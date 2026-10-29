import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {clone as cloneSkeleton} from 'three/addons/utils/SkeletonUtils.js';
const game=window.NightShift3D;
const mount=document.getElementById('threeMount');
const scene=new THREE.Scene();scene.background=new THREE.Color(0x080b18);scene.fog=new THREE.FogExp2(0x080b18,.017);
const renderer=new THREE.WebGLRenderer({antialias:true,alpha:false});renderer.setPixelRatio(Math.min(devicePixelRatio,1.5));renderer.shadowMap.enabled=true;renderer.shadowMap.type=THREE.PCFSoftShadowMap;renderer.outputColorSpace=THREE.SRGBColorSpace;mount.appendChild(renderer.domElement);
const ambient=new THREE.HemisphereLight(0xdbe8ff,0x443448,3.0);scene.add(ambient);let sun=new THREE.DirectionalLight(0xfff1d8,3.4);sun.position.set(-8,17,11);scene.add(sun);const nightColor=new THREE.Color(0x080b18),dayColor=new THREE.Color(0x151b2b);let nightMix=0;
const stage=new THREE.Group();scene.add(stage);
const groundMat=new THREE.MeshStandardMaterial({color:0x242332,roughness:.85});
const colors={wall:0x3d374b,floor:0x604080,dj:0x34254c,bar:0x8a5036,speaker:0x1c1d29,light:0x7c3798,sofa:0x833c63,wc:0x546b87,plant:0x276a55,table:0x53475d,door:0x96577c,poster:0xbf347d,rail:0x67556b,plant2:0x398064,stool:0x9b6a54,laser:0x5c2f88};
const mats={};for(const [k,c] of Object.entries(colors))mats[k]=new THREE.MeshStandardMaterial({color:c,roughness:.62,metalness:k==='speaker'?.32:.08});
const geometryCache=new Map();const geo=(w,h,d)=>{const key=w+','+h+','+d;let g=geometryCache.get(key);if(!g){g=new THREE.BoxGeometry(w,h,d);geometryCache.set(key,g)}return g};
const floorGeo=geo(.99,.08,.99),boxGeo=geo(.8,.7,.8),wallGeo=geo(1,.85,1);
const tileGroups=new Map(),lights=[],peopleMeshes=[],danceGlows=[],beams=[];
// Original artwork: alpha-cutout billboards remain legible while camera rotates.
const artNames=['dj','bar','speaker','light','sofa','wc','plant','table','door','poster','rail','plant2','stool','laser','wall','entrance','floor'];
const art={};const textureLoader=new THREE.TextureLoader();
for(const name of artNames){textureLoader.load('assets/club/'+name+'.webp',texture=>{texture.colorSpace=THREE.SRGBColorSpace;texture.anisotropy=Math.min(renderer.capabilities.getMaxAnisotropy(),8);art[name]=new THREE.MeshBasicMaterial({map:texture,transparent:true,alphaTest:.16,depthWrite:true,side:THREE.DoubleSide});lastSignature='';},undefined,()=>{});}
const artSizes={dj:[1.55,1.55],bar:[1.7,1.55],speaker:[1.2,1.9],light:[1.1,1.35],sofa:[1.6,1.2],wc:[1.7,1.6],plant:[1.0,1.3],plant2:[1.25,1.65],table:[1.15,1.2],door:[1.35,1.7],poster:[1.35,1.45],rail:[1.6,.95],stool:[.95,1.3],laser:[1.1,1.1],wall:[1.55,1.5],entrance:[1.6,1.7]};
// Real 3D DJ booth: loaded asynchronously and cloned for every booth tile.
let djModel=null;
new GLTFLoader().load('assets/models/dj.glb',gltf=>{
 const model=gltf.scene;
 // The placement anchor is the exact center of the first tile. The booth extends
 // from z=-0.5 to z=+1.5, covering the two reserved tiles, not their boundary.
 model.updateMatrixWorld(true);
 let bounds=new THREE.Box3().setFromObject(model);
 let size=bounds.getSize(new THREE.Vector3());
 // Align the model's longest horizontal dimension with the two-tile Z footprint.
 if(size.x>size.z){model.rotation.y=Math.PI/2;model.updateMatrixWorld(true);bounds.setFromObject(model);size=bounds.getSize(new THREE.Vector3());}
 // Scale horizontal axes independently: generated GLBs often have wide empty
 // margins or unusual proportions. The visible model fills both tiles.
 model.scale.set(
   model.scale.x*.90/Math.max(size.x,.001),
   model.scale.y*Math.min(1.25/Math.max(size.y,.001),1.8),
   model.scale.z*1.88/Math.max(size.z,.001)
 );
 model.updateMatrixWorld(true);
 bounds.setFromObject(model);
 const center=bounds.getCenter(new THREE.Vector3());
 // World-space booth center is (0, 0, +0.5) relative to its first tile.
 model.position.x-=center.x;
 model.position.y-=bounds.min.y-.09;
 model.position.z+=.5-center.z;
 model.updateMatrixWorld(true);
 model.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true;}});
 djModel=model;lastSignature='';
},undefined,err=>console.warn('DJ GLB could not be loaded; fallback art remains available',err));
// Additional textured Meshy assets. Loaded once, cloned per placed object.
const extraModels={};
const modelLoader=new GLTFLoader();
for(const [kind,config] of Object.entries({
 bar:{width:.92,height:1.22,depth:1.85},speaker:{width:.70,height:1.75,depth:.64},
 rail:{width:.98,height:1.05,depth:.32},entrance:{width:1.96,height:1.85,depth:.78},
 floor:{width:1,height:.16,depth:1,tile:true},wc:{width:.92,height:1.65,depth:1.82},
 table:{width:.82,height:1.12,depth:.82},stool:{width:.65,height:.95,depth:.65},light:{width:.72,height:1.32,depth:.72},laser:{width:.72,height:1.15,depth:.72},
 sofa:{width:.92,height:1.05,depth:1.83},plant:{width:.88,height:1.65,depth:.88},plant2:{width:.88,height:1.65,depth:.88}
})){
 modelLoader.load('assets/models/'+(kind==='plant'?'plant2':kind)+'.glb',gltf=>{
  const model=gltf.scene;model.updateMatrixWorld(true);
  let bounds=new THREE.Box3().setFromObject(model),dims=bounds.getSize(new THREE.Vector3());
  // The dance tile must have exactly one grid-cell footprint on X/Z.
  // Scale all other props uniformly to avoid distorting the original Meshy model.
  // Meshy bar and sofa are naturally LONG along their local X axis.
  // Turn the model 90 degrees so that its long side follows the multi-cell Z footprint.
  // Crucially: use ONE uniform scale factor. Independent XYZ scaling distorted these props.
  const multiCellLengths={bar:2,sofa:2,wc:2};
  if(kind==='entrance'){
   if(dims.z>dims.x){model.rotation.y=Math.PI/2;model.updateMatrixWorld(true);bounds.setFromObject(model);dims=bounds.getSize(new THREE.Vector3());}
   // The entrance spans the two missing perimeter wall tiles, x=7 and x=8.
   // Use the full width of the opening, preserving the original proportions.
   const factor=1.98/Math.max(dims.x,.001);
   model.scale.multiplyScalar(factor);
  }
  if(kind in multiCellLengths){
   const horizontalLongAxis=dims.x>=dims.z?'x':'z';
   if(horizontalLongAxis==='x')model.rotation.y=Math.PI/2;
   // Fill most of the reserved length while keeping the original GLB proportions.
   // The furniture is centred across its footprint rather than between unrelated cells.
   const originalLength=Math.max(dims.x,dims.z);
   const desiredLength=multiCellLengths[kind]-.22;
   const factor=desiredLength/Math.max(originalLength,.001);
   model.scale.multiplyScalar(factor);
  }else if(kind==='entrance'){
   // Already scaled uniformly to the 2-cell doorway.
  }else if(config.tile){
   // Dance tiles require an exact 1x1 seam-free footprint.
   model.scale.set(config.width/Math.max(dims.x,.001),config.height/Math.max(dims.y,.001),config.depth/Math.max(dims.z,.001));
  }else{
   const f=Math.min(config.width/Math.max(dims.x,.001),config.height/Math.max(dims.y,.001),config.depth/Math.max(dims.z,.001));
   model.scale.multiplyScalar(f);
  }
  model.updateMatrixWorld(true);bounds=new THREE.Box3().setFromObject(model);
  const center=bounds.getCenter(new THREE.Vector3());
  model.position.x-=center.x;model.position.z-=center.z;
  if(kind in multiCellLengths)model.position.z+=(multiCellLengths[kind]-1)/2;
  model.position.y-=bounds.min.y-(config.tile?.005:.08);
  model.traverse(o=>{if(o.isMesh){o.castShadow=!config.tile;o.receiveShadow=true}});
  extraModels[kind]=model;lastSignature='';
 },undefined,err=>console.warn('Cannot load '+kind+' GLB, using existing artwork',err));
}

// Bouncer is a static entrance prop, shared between scene rebuilds.
let bouncerModel=null;
let entranceGuard=null;
let bouncerClip=null;
let bouncerMixer=null;
let bouncerAction=null;
let bouncerWasRunning=false;
modelLoader.load('assets/characters/bouncer.glb',gltf=>{
 const model=gltf.scene;
 model.updateMatrixWorld(true);
 const bounds=new THREE.Box3().setFromObject(model);
 const size=bounds.getSize(new THREE.Vector3());
 if(!Number.isFinite(size.y)||size.y<.001){console.warn('Invalid bouncer model dimensions');return}
 model.scale.multiplyScalar(1.52/size.y);
 model.updateMatrixWorld(true);
 const fitted=new THREE.Box3().setFromObject(model),center=fitted.getCenter(new THREE.Vector3());
 model.position.set(-center.x,.08-fitted.min.y,-center.z);
 model.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true}});
 bouncerModel=model;
 bouncerClip=gltf.animations?.find(clip=>/idle|guard|stand|breath|look|watch/i.test(clip.name))||gltf.animations?.[0]||null;
 console.info('NightShift bouncer animations:',gltf.animations?.map(a=>a.name)||[]);
 lastSignature='';
},undefined,err=>console.warn('Cannot load bouncer GLB',err));

// A full-height perimeter. Wall segments sit on the INNER edge of their
// boundary tiles, with a small overlap so Meshy trim never exposes seams.
let wallModel=null;
modelLoader.load('assets/models/wall.glb',gltf=>{
 const m=gltf.scene;
 let b=new THREE.Box3().setFromObject(m),d=b.getSize(new THREE.Vector3());
 // Align the model's long horizontal axis with the wall's local X axis.
 if(d.z>d.x){m.rotation.y=Math.PI/2;m.updateMatrixWorld(true);b.setFromObject(m);d=b.getSize(new THREE.Vector3());}
 const scale=1.035/Math.max(d.x,.001); // 3.5% overlap at segment joins
 m.scale.multiplyScalar(scale);
 m.updateMatrixWorld(true);
 const bb=new THREE.Box3().setFromObject(m),c=bb.getCenter(new THREE.Vector3());
 m.position.set(-c.x,-bb.min.y,-c.z);
 m.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true}});
 wallModel=m;lastSignature='';
},undefined,err=>console.warn('Wall GLB unavailable',err));
let posterWallModel=null;
modelLoader.load('assets/models/poster.glb',gltf=>{
 const m=gltf.scene;m.updateMatrixWorld(true);
 let b=new THREE.Box3().setFromObject(m),d=b.getSize(new THREE.Vector3());
 if(d.z>d.x){m.rotation.y=Math.PI/2;m.updateMatrixWorld(true);b.setFromObject(m);d=b.getSize(new THREE.Vector3());}
 // Match wall segment width exactly, including the seam overlap.
 m.scale.multiplyScalar(1.035/Math.max(d.x,.001));
 m.updateMatrixWorld(true);b.setFromObject(m);
 const c=b.getCenter(new THREE.Vector3());
 m.position.set(-c.x,-b.min.y,-c.z);
 m.traverse(o=>{if(o.isMesh){o.castShadow=true;o.receiveShadow=true}});
 posterWallModel=m;lastSignature='';
},undefined,e=>console.warn('Poster wall model unavailable',e));
const livePosters=[];
let livePosterName='',livePosterActive=false;
function makeLivePosterTexture(name){
 const canvas=document.createElement('canvas');canvas.width=768;canvas.height=1024;
 const ctx=canvas.getContext('2d');
 const gradient=ctx.createLinearGradient(0,0,768,1024);
 gradient.addColorStop(0,'#21142e');gradient.addColorStop(.65,'#100d1d');gradient.addColorStop(1,'#32143d');
 ctx.fillStyle=gradient;ctx.fillRect(0,0,768,1024);
 ctx.strokeStyle='#e04bb7';ctx.lineWidth=15;ctx.strokeRect(24,24,720,976);
 ctx.fillStyle='#ed6dcb';ctx.fillRect(65,92,638,6);
 ctx.textAlign='center';ctx.fillStyle='#d4b4e9';ctx.font='bold 44px sans-serif';ctx.fillText('NIGHTSHIFT',384,185);
 ctx.font='bold 35px sans-serif';ctx.fillStyle='#ed6dcb';ctx.fillText('●  NOW PLAYING',384,295);
 const words=String(name||'DJ').trim().toUpperCase().split(/\s+/);
 const lines=[];let line='';
 for(const word of words){const candidate=line?line+' '+word:word;if(ctx.measureText(candidate).width>630&&line){lines.push(line);line=word}else line=candidate}
 if(line)lines.push(line);
 const display=lines.slice(0,3);
 let fontSize=112;
 do{ctx.font='900 '+fontSize+'px sans-serif';if(Math.max(...display.map(t=>ctx.measureText(t).width))<=640)break;fontSize-=4}while(fontSize>42);
 ctx.fillStyle='#ffffff';const lineHeight=fontSize*1.12,firstY=570-(display.length-1)*lineHeight/2;
 display.forEach((text,i)=>ctx.fillText(text,384,firstY+i*lineHeight));
 ctx.fillStyle='#e04bb7';ctx.fillRect(65,795,638,5);
 ctx.fillStyle='#c7b1d6';ctx.font='bold 33px sans-serif';ctx.fillText('UNDERGROUND ALL NIGHT',384,865);
 const texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.SRGBColorSpace;texture.anisotropy=Math.min(renderer.capabilities.getMaxAnisotropy(),8);
 return texture;
}
let livePosterMaterial=null;
function updateLivePosters(){
 const active=!!game.running;
 const selected=document.getElementById('djSelect');
 const name=selected?.selectedOptions?.[0]?.textContent?.split(' · ')[0]||'DJ';
 if(active!==livePosterActive||active&&name!==livePosterName){
  livePosterActive=active;livePosterName=name;
  if(livePosterMaterial){livePosterMaterial.map?.dispose();livePosterMaterial.dispose();livePosterMaterial=null}
  if(active)livePosterMaterial=new THREE.MeshBasicMaterial({map:makeLivePosterTexture(name),side:THREE.DoubleSide,depthWrite:true});
 }
 for(const panel of livePosters){panel.visible=active;if(active)panel.material=livePosterMaterial}
}
function perimeterWall(parent,x,y,poster=false){
 if(y===game.N-1&&(x===game.N/2-1||x===game.N/2))return;
 const wall=new THREE.Group();
 // Each poster wall's local +Z faces the club interior on all four edges.
 if(y===0){wall.position.z=.5;}
 else if(y===game.N-1){wall.position.z=-.5;if(poster)wall.rotation.y=Math.PI;}
 else if(x===0){wall.position.x=.5;wall.rotation.y=Math.PI/2;}
 else if(x===game.N-1){wall.position.x=-.5;wall.rotation.y=poster?-Math.PI/2:Math.PI/2;}
 if(poster&&posterWallModel)wall.add(posterWallModel.clone(true));
 else if(poster&&!posterWallModel&&wallModel){wall.add(wallModel.clone(true));box(wall,.68,.82,.06,neonPink,0,1.0,.15);}
 else if(wallModel)wall.add(wallModel.clone(true));
 else box(wall,1.035,1.65,.24,mats.wall,0,.825,0);
 if(poster){
  // Separate luminous event graphic, placed slightly in front of the GLB artwork.
  const panel=new THREE.Mesh(new THREE.PlaneGeometry(.76,1.10),new THREE.MeshBasicMaterial({color:0x24142c,side:THREE.DoubleSide}));
  panel.position.set(0,.91,.18);panel.visible=false;panel.renderOrder=5;
  wall.add(panel);livePosters.push(panel);
 }
 parent.add(wall);
 if((x===0||x===game.N-1)&&(y===0||y===game.N-1)){
  const corner=new THREE.Group();corner.rotation.y=Math.PI/2;
  corner.position.x=x===0?.5:-.5;
  corner.position.z=y===0?.5:-.5;
  if(wallModel)corner.add(wallModel.clone(true));else box(corner,1.035,1.65,.24,mats.wall,0,.825,0);
  parent.add(corner);
 }
}
// The DJ is represented by the music player and live event posters.
// Raised illuminated venue sign, anchored over the permanent entrance.
let entranceSign=null,entranceSignName='';
function refreshEntranceSign(){
 const name=String(game.clubName||'THE BASEMENT').trim().toUpperCase();
 if(name===entranceSignName&&entranceSign){entranceSign.position.z=(game.N-1)/2-.35;return;}
 entranceSignName=name;
 if(entranceSign){stage.remove(entranceSign);entranceSign.traverse(o=>{if(o.isMesh&&o.userData.signTexture)o.userData.signTexture.dispose()});entranceSign=null}
 const canvas=document.createElement('canvas');canvas.width=1024;canvas.height=256;
 const ctx=canvas.getContext('2d');ctx.fillStyle='#100f1b';ctx.fillRect(0,0,1024,256);
 ctx.strokeStyle='#b14dbe';ctx.lineWidth=13;ctx.strokeRect(8,8,1008,240);
 ctx.fillStyle='#65f2d4';ctx.textAlign='center';ctx.textBaseline='middle';
 let font=112;do{ctx.font='900 '+font+'px sans-serif';if(ctx.measureText(name).width<930)break;font-=4}while(font>28);
 ctx.shadowColor='#39e8c4';ctx.shadowBlur=24;ctx.fillText(name,512,133);
 const texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.SRGBColorSpace;
 const material=new THREE.MeshBasicMaterial({map:texture,side:THREE.DoubleSide});
 const sign=new THREE.Group();sign.position.set(0,2.20,(game.N-1)/2-.35);
 const board=new THREE.Mesh(new THREE.BoxGeometry(2.45,.69,.10),new THREE.MeshStandardMaterial({color:0x17131e,metalness:.45,roughness:.38}));sign.add(board);
 const face=new THREE.Mesh(new THREE.PlaneGeometry(2.37,.60),material);face.position.z=.061;face.userData.signTexture=texture;sign.add(face);
 const back=new THREE.Mesh(new THREE.PlaneGeometry(2.37,.60),material);back.position.z=-.061;back.rotation.y=Math.PI;sign.add(back);
 stage.add(sign);entranceSign=sign;
}
const billboards=[];function artwork(parent,type){if(!art[type])return false;const [w,h]=artSizes[type]||[1.3,1.3];const plane=new THREE.Mesh(new THREE.PlaneGeometry(w,h),art[type]);plane.position.y=h/2+.03;plane.rotation.y=Math.PI/4;plane.renderOrder=2;parent.add(plane);billboards.push(plane);return true;}

function mesh(g,m,x,y,z,parent){let o=new THREE.Mesh(g,m);o.position.set(x,y,z);(parent||stage).add(o);return o}
function box(parent,w,h,d,mat,x=0,y=0,z=0){return mesh(geo(w,h,d),mat,x,y,z,parent)}
function emissive(hex,intensity=1.5){return new THREE.MeshStandardMaterial({color:hex,emissive:hex,emissiveIntensity:intensity,roughness:.35})}
const neonPink=emissive(0xff40be,2),neonBlue=emissive(0x3b9bff,2),neonViolet=emissive(0x9950ff,2),gold=emissive(0xffb85e,.8);
const danceGlowMaterial=new THREE.MeshBasicMaterial({color:0x9b53ff,transparent:true,opacity:0,depthWrite:false,side:THREE.DoubleSide});
function addDanceGlow(parent){const glow=new THREE.Mesh(new THREE.PlaneGeometry(.985,.985),danceGlowMaterial.clone());glow.rotation.x=-Math.PI/2;glow.position.y=.19;glow.renderOrder=3;parent.add(glow);danceGlows.push({mesh:glow,x:parent.parent.position.x,z:parent.parent.position.z});}
function fixture(parent,type){
 if(type==='dj'&&djModel){box(parent,.98,.035,1.98,mats.dj,0,.07,.5);parent.add(djModel.clone(true));return;}
 if(extraModels[type]){parent.add(extraModels[type].clone(true));if(type==='floor')addDanceGlow(parent);return;}
 if(type==='dj_back'||type==='door'||type==='wall'||type?.startsWith('occupied:'))return;
 if(type!=='floor'&&type!=='dj'&&artwork(parent,type))return;
 
 if(type==='floor'){box(parent,1,.03,1,mats.floor,0,.06,0);addDanceGlow(parent);return}
 if(type==='dj'){box(parent,.90,.75,1.88,mats.dj,0,.44,.5);box(parent,.83,.11,.06,neonBlue,0,.57,.34);for(let i=-1;i<=1;i++){let disc=new THREE.Mesh(new THREE.CylinderGeometry(.14,.14,.025,20),mats.speaker);disc.position.set(i*.27,.84,-.04);parent.add(disc)}return}
 if(type==='bar'){box(parent,.98,.83,.57,mats.bar,0,.47,0);box(parent,1.04,.1,.69,gold,0,.93,0);for(let i=-1;i<=1;i++)box(parent,.08,.25,.08,neonBlue,i*.25,1.12,-.1);return}
 if(type==='speaker'){box(parent,.63,1.5,.54,mats.speaker,0,.8,0);for(let y of [.52,1.15]){let d=new THREE.Mesh(new THREE.CylinderGeometry(.2,.2,.03,24),mats.wall);d.rotation.x=Math.PI/2;d.position.set(0,y,.29);parent.add(d)}return}
 if(type==='sofa'){box(parent,.9,.33,.72,mats.sofa,0,.3,0);box(parent,.9,.48,.17,mats.sofa,0,.65,-.28);return}
 if(type==='wc'){box(parent,.72,1.65,.7,mats.wall,0,.87,0);box(parent,.42,.05,.03,neonBlue,0,1.45,.37);return}
 if(type==='table'){box(parent,.77,.08,.77,mats.table,0,.65,0);box(parent,.12,.6,.12,mats.speaker,0,.33,0);return}
 if(type==='stool'){box(parent,.44,.12,.44,mats.bar,0,.55,0);box(parent,.12,.48,.12,mats.speaker,0,.3,0);return}
 if(type==='rail'){box(parent,1,.08,.08,mats.wall,0,.67,0);for(let x of [-.43,.43])box(parent,.07,.7,.07,mats.speaker,x,.35,0);return}
 
 if(type==='poster'){box(parent,.75,.95,.09,neonPink,0,.9,0);box(parent,.58,.72,.11,mats.speaker,0,.9,.07);return}
 if(type==='plant'||type==='plant2'){box(parent,.48,.44,.48,mats.bar,0,.24,0);let crown=new THREE.Mesh(new THREE.IcosahedronGeometry(type==='plant2'?.55:.38,1),mats.plant);crown.position.y=type==='plant2'?1.05:.77;parent.add(crown);return}
 if(type==='light'||type==='laser'){box(parent,.35,.55,.35,mats.speaker,0,.5,0);box(parent,.28,.1,.28,type==='laser'?neonPink:neonViolet,0,.8,0);return}
}
function rebuild(){clearDragPreview();if(entranceGuard){if(bouncerMixer){bouncerMixer.stopAllAction();bouncerMixer.uncacheRoot(entranceGuard.userData.actor);bouncerMixer=null;bouncerAction=null}stage.remove(entranceGuard);entranceGuard=null;bouncerWasRunning=false}for(let o of tileGroups.values())stage.remove(o);tileGroups.clear();lights.length=0;beams.length=0;billboards.length=0;danceGlows.length=0;livePosters.length=0;const map=game.map;for(let y=0;y<game.N;y++)for(let x=0;x<game.N;x++){
 const group=new THREE.Group();group.position.set(x-(game.N-1)/2,0,y-(game.N-1)/2);stage.add(group);tileGroups.set(x+','+y,group);
 box(group,1,.14,1,(x+y)%2?groundMat:mats.speaker,0,-.07,0);
 const type=map[y]?.[x];if(type==='wall'||type==='poster'&&(x===0||y===0||x===game.N-1||y===game.N-1))perimeterWall(group,x,y,type==='poster');if(type&&type!=='wall'&&!(type==='poster'&&(x===0||y===0||x===game.N-1||y===game.N-1))&&type!=='dj_back'&&!type.startsWith('occupied:')){const item=new THREE.Group();item.rotation.y=(game.rotations[x+','+y]||0)*Math.PI/2;group.add(item);item.userData.furniture=true;fixture(item,type);}if(x===game.N/2-1&&y===game.N-1){const entry=new THREE.Group();entry.position.set(.5,0,-.5);group.add(entry);if(extraModels.entrance)entry.add(extraModels.entrance.clone(true));else artwork(entry,'entrance');
 if(bouncerModel){
  // Position in WORLD tile coordinates: outside the southern entrance.
  // Do not parent the guard to the entrance GLB, whose geometry can have offsets.
  const guard=new THREE.Group();
  guard.position.set(1.42,0,(game.N-1)/2+.68);
  guard.rotation.y=0;
  const actor=cloneSkeleton(bouncerModel);
  guard.add(actor);
  guard.userData.actor=actor;
  if(bouncerClip){bouncerMixer=new THREE.AnimationMixer(actor);bouncerAction=bouncerMixer.clipAction(bouncerClip);bouncerAction.setLoop(THREE.LoopRepeat,Infinity)}
  stage.add(guard);
  entranceGuard=guard;
 }
 }
 if(['dj','laser','light'].includes(type)){
 const color=type==='dj'?0x8e51ff:type==='laser'?0xff32c6:0x9367ff;
 // Actual SpotLight + a local PointLight for visible illumination of nearby props.
 const light=new THREE.SpotLight(color,0,type==='laser'?13:11,type==='laser'?.19:.55,.42,1.3);
 light.position.set(0,type==='dj'?2.3:1.65,0);
 const target=new THREE.Object3D();target.position.set(0,.08,1.4);group.add(target);light.target=target;group.add(light);
 const spill=new THREE.PointLight(color,0,type==='laser'?3.5:5,1.7);
 spill.position.set(0,1.15,0);group.add(spill);
 // Transparent cone makes the beam perceptible even without volumetric fog.
 const length=type==='laser'?4.4:3.1;
 const beamMat=new THREE.MeshBasicMaterial({color,transparent:true,opacity:0,depthWrite:false,side:THREE.DoubleSide,blending:THREE.AdditiveBlending});
 const beam=new THREE.Mesh(new THREE.ConeGeometry(type==='laser'?.045:.36,length,12,1,true),beamMat);
 beam.position.set(0,1.65-length/2,0);
 beam.frustumCulled=false;group.add(beam);beams.push(beam);
 lights.push({light,target,spill,beam,type,baseX:x,baseY:y});
}
 }}
let lastSignature='';function signature(){return game.N+'#'+game.map.map(r=>r.join('|')).join(';')+'#'+JSON.stringify(game.rotations)}
// Each exported GLB owns its mesh, rig and animation. Never retarget between rigs.
const humanColors=[0xee559d,0x7d98e8,0xc49fef,0xe6a759,0x54c9b6,0xd979aa];
const raverModels=[
 {id:'m',states:{idle:null,walk:null,dance:null}},
 {id:'f',states:{idle:null,walk:null,dance:null}},
 {id:'fashion_f',states:{idle:null,walk:null,dance:null}},
 {id:'baggy_m',states:{idle:null,walk:null,dance:null}},
 {id:'jungle_f',states:{idle:null,walk:null,dance:null}}
];
const peopleMap=new Map();
const humanHeight=1.48;
function makeRaverFallback(p){
 const group=new THREE.Group(),color=humanColors[(p.variant||0)%humanColors.length];
 const body=new THREE.Mesh(new THREE.CylinderGeometry(.13,.16,.48,7),new THREE.MeshStandardMaterial({color}));
 body.position.y=.53;group.add(body);
 const head=new THREE.Mesh(new THREE.SphereGeometry(.105,8,6),new THREE.MeshStandardMaterial({color:0xd7a58d}));
 head.position.y=.94;group.add(head);
 group.userData.fallbackBody=body;return group;
}
// Load character GLBs on demand: the empty club should not decode all 15 models.
const characterLoads=new Map();
function requestCharacterState(index,mode){
 const model=raverModels[index];
 if(!model||model.states[mode])return;
 const key=index+':'+mode;
 if(characterLoads.has(key))return;
 const url='assets/characters/'+(['fashion_f','baggy_m','jungle_f'].includes(model.id)?model.id:'raver_'+model.id)+'_'+mode+'.glb';
 characterLoads.set(key,true);
 modelLoader.load(url,gltf=>{
  const template=gltf.scene;
  template.updateMatrixWorld(true);
  const bounds=new THREE.Box3().setFromObject(template),size=bounds.getSize(new THREE.Vector3());
  if(!Number.isFinite(size.y)||size.y<.001){console.warn('Invalid GLB character bounds',url);characterLoads.delete(key);return}
  template.scale.multiplyScalar(humanHeight/size.y);
  template.updateMatrixWorld(true);
  const fitted=new THREE.Box3().setFromObject(template),center=fitted.getCenter(new THREE.Vector3());
  template.position.x-=center.x;template.position.z-=center.z;template.position.y-=fitted.min.y;
  template.traverse(obj=>{if(obj.isMesh){obj.castShadow=true;obj.receiveShadow=true;obj.frustumCulled=false}});
  model.states[mode]={template,clip:gltf.animations[0]||null};
  console.info('NightShift: character state ready',url);
 },undefined,err=>{characterLoads.delete(key);console.warn('Character state failed to load',url,err)});
}
function guestModelIndex(p){return (p.variant||0)%raverModels.length}
function releaseGuest(obj){
 const ud=obj.userData;
 if(ud.mixer){ud.mixer.stopAllAction();if(ud.character)ud.mixer.uncacheRoot(ud.character)}
 if(ud.character){obj.remove(ud.character);ud.character=null}
 if(ud.fallback){obj.remove(ud.fallback);ud.fallback=null}
 stage.remove(obj);
}
function showGuestMode(obj,p,mode){
 const ud=obj.userData,index=guestModelIndex(p),model=raverModels[index];
 requestCharacterState(index,mode);
 const desired=model.states[mode]?mode:model.states.idle?'idle':model.states.walk?'walk':model.states.dance?'dance':null;
 if(ud.current===desired&&ud.character)return;
 if(ud.mixer){ud.mixer.stopAllAction();if(ud.character)ud.mixer.uncacheRoot(ud.character);ud.mixer=null}
 if(ud.character){obj.remove(ud.character);ud.character=null}
 if(!desired){
  if(!ud.fallback){ud.fallback=makeRaverFallback(p);obj.add(ud.fallback)}
  ud.current=null;return;
 }
 if(ud.fallback){obj.remove(ud.fallback);ud.fallback=null}
 const asset=model.states[desired],character=cloneSkeleton(asset.template);
 obj.add(character);ud.character=character;ud.current=desired;
 if(asset.clip){
  const mixer=new THREE.AnimationMixer(character),action=mixer.clipAction(asset.clip);
  action.setLoop(THREE.LoopRepeat,Infinity);action.play();ud.mixer=mixer;
 }
}
function makePerson(p){
 const group=new THREE.Group();
 group.userData={current:null,character:null,mixer:null,fallback:null,lastPos:null,pendingMode:null,pendingSince:0};
 showGuestMode(group,p,'idle');stage.add(group);return group;
}
function updatePeople(t,dt){
 const alive=new Set(game.people);
 for(const [p,obj] of peopleMap)if(!alive.has(p)){releaseGuest(obj);peopleMap.delete(p)}
 for(const p of game.people){
  let o=peopleMap.get(p);if(!o){o=makePerson(p);peopleMap.set(p,o)}
  const previous=o.userData.lastPos;
  const movement=previous?Math.hypot(p.x-previous.x,p.y-previous.y)/Math.max(dt,.001):0;
  o.userData.lastPos={x:p.x,y:p.y};
  o.position.set(p.x-(game.N-1)/2,0,p.y-(game.N-1)/2);
  const onDancefloor=game.map[Math.round(p.y)]?.[Math.round(p.x)]==='floor';
  const mode=movement>.055?'walk':p.state==='dance'&&!p.leaving&&onDancefloor?'dance':'idle';
  // Avoid recreating a skinned GLB on every tiny velocity fluctuation.
  // A transition must remain stable before loading the next animation.
  const ud=o.userData;
  if(mode!==ud.pendingMode){ud.pendingMode=mode;ud.pendingSince=t}
  if(!ud.character||mode!==ud.current&&t-ud.pendingSince>.65||ud.current!==mode&&raverModels[guestModelIndex(p)].states[mode]&&t-ud.pendingSince>.65)showGuestMode(o,p,mode);
  if(o.userData.mixer)o.userData.mixer.update(Math.min(dt,.06));
  else if(o.userData.fallback?.userData.fallbackBody){
   o.userData.fallback.userData.fallbackBody.position.y=.53+(mode==='dance'?.07*Math.sin(t*8+p.x*2):0);
  }
  const next=p.path?.[0];
  if(next&&Math.hypot(next.x-p.x,next.y-p.y)>.05)o.rotation.y=Math.atan2(next.x-p.x,next.y-p.y);
  else if(mode==='dance')o.rotation.y+=Math.sin(t*1.4+(p.variant||0))*.003;
 }
}
const camera=new THREE.OrthographicCamera(-11,11,8,-8,.1,160);const target=new THREE.Vector3(0,0,0);let azimuth=Math.PI/4,elevation=.85,distance=25,ortho=12;
function cameraUpdate(){camera.position.set(target.x+distance*Math.cos(elevation)*Math.sin(azimuth),target.y+distance*Math.sin(elevation),target.z+distance*Math.cos(elevation)*Math.cos(azimuth));camera.lookAt(target);let w=mount.clientWidth||1000,h=mount.clientHeight||650,aspect=w/h;camera.left=-ortho*aspect;camera.right=ortho*aspect;camera.top=ortho;camera.bottom=-ortho;camera.updateProjectionMatrix();renderer.setSize(w,h,false)}
const ray=new THREE.Raycaster(),pointer=new THREE.Vector2(),plane=new THREE.Plane(new THREE.Vector3(0,1,0),0);let down=null;
function hit(e){let r=renderer.domElement.getBoundingClientRect();pointer.set(((e.clientX-r.left)/r.width)*2-1,-((e.clientY-r.top)/r.height)*2+1);ray.setFromCamera(pointer,camera);let out=new THREE.Vector3();if(!ray.ray.intersectPlane(plane,out))return null;return {x:Math.round(out.x+(game.N-1)/2),y:Math.round(out.z+(game.N-1)/2)}}
// Furniture editor: hover reveals a rotate handle, dragging a purchased object
// moves it at no charge. Empty-floor drag still orbits the camera.
const handle=document.createElement('button');handle.type='button';handle.id='objectRotate';handle.title='Повернуть предмет на 90°';handle.textContent='↻';handle.style.cssText='position:absolute;z-index:10;display:none;width:37px;height:37px;border:1px solid #9d74e9;border-radius:50%;background:#251632;color:#fff;font-size:27px;line-height:1;display:none;align-items:center;justify-content:center;padding:0;text-align:center;cursor:pointer;box-shadow:0 0 12px #c64efc99;pointer-events:auto';mount.appendChild(handle);
const tip=document.createElement('div');tip.id='editTip';tip.textContent='Перетащить · ↻ повернуть';tip.style.cssText='position:absolute;z-index:9;display:none;pointer-events:none;color:#d9c9ef;background:#101323dc;border:1px solid #5b4b82;border-radius:6px;padding:5px 8px;font-size:11px';mount.appendChild(tip);
let dragPreview=null,dragSource=null;
function clearDragPreview(){
 if(dragPreview){stage.remove(dragPreview);dragPreview.traverse(o=>{if(o.isMesh&&o.material&&o.userData.previewMaterial)o.material.dispose()});dragPreview=null}
 if(dragSource){dragSource.visible=true;dragSource=null}
}
function previewValid(d){const old=game.occupiedCells(d.x,d.y);const rot=game.rotations[d.x+','+d.y]||0;const length={dj:2,bar:2,sofa:2,wc:2}[d.type]||1;const delta=[[0,1],[1,0],[0,-1],[-1,0]][((rot%4)+4)%4];const cells=Array.from({length},(_,i)=>({x:d.nx+i*delta[0],y:d.ny+i*delta[1]}));return cells.every(c=>c.x>=1&&c.y>=1&&c.x<game.N-1&&c.y<game.N-1&&(!game.map[c.y][c.x]||old.some(v=>v.x===c.x&&v.y===c.y)))}
function updateDragPreview(d){
 if(!dragPreview){
  const source=tileGroups.get(d.x+','+d.y);
  const original=source?.children.find(c=>c.userData.furniture);
  if(!original)return;
  dragPreview=original.clone(true);
  dragPreview.traverse(o=>{
   if(o.isMesh){const m=o.material?.clone?.();if(m){m.transparent=true;m.opacity=.66;m.depthWrite=false;o.material=m;o.userData.previewMaterial=true}}
  });
  stage.add(dragPreview);
  dragSource=original;dragSource.visible=false;
 }
 dragPreview.position.set(d.nx-(game.N-1)/2,.13,d.ny-(game.N-1)/2);
 const valid=previewValid(d);
 dragPreview.traverse(o=>{if(o.isMesh&&o.userData.previewMaterial){o.material.color.setHex(valid?0x90ffbf:0xff657e);o.material.needsUpdate=true}});
}
let hovered=null,dragObj=null,overRotateHandle=false;
function nearRotateHandle(e){if(handle.style.display==='none')return false;const r=handle.getBoundingClientRect();const x=Math.max(r.left,Math.min(e.clientX,r.right)),y=Math.max(r.top,Math.min(e.clientY,r.bottom));return Math.hypot(e.clientX-x,e.clientY-y)<95;}
function objectAt(e){const c=hit(e);if(!c)return null;const a=game.anchor(c.x,c.y),type=game.map[a.y]?.[a.x];return type&&game.types[type]&&type!=='floor'&&type!=='poster'?{x:a.x,y:a.y,type}:null}
function showHandle(o){hovered=o;if(!o||game.running){handle.style.display='none';tip.style.display='none';return}const p=new THREE.Vector3(o.x-(game.N-1)/2,1.4,o.y-(game.N-1)/2);p.project(camera);const w=mount.clientWidth,h=mount.clientHeight;let px=(p.x+1)*w/2,py=(1-p.y)*h/2;handle.style.left=Math.max(5,Math.min(w-42,px+17))+'px';handle.style.top=Math.max(5,Math.min(h-42,py-18))+'px';handle.style.display='block';tip.style.left=Math.max(5,Math.min(w-180,px-75))+'px';tip.style.top=Math.max(5,py-55)+'px';tip.style.display='block'}
handle.addEventListener('pointerenter',()=>{overRotateHandle=true});
handle.addEventListener('pointerleave',e=>{overRotateHandle=false;if(!nearRotateHandle(e))showHandle(null)});
handle.addEventListener('pointerdown',e=>e.stopPropagation());handle.addEventListener('click',e=>{e.stopPropagation();if(hovered){if(!game.rotateObject(hovered.x,hovered.y))console.info('Rotation blocked by occupied or out-of-bounds tiles');showHandle(hovered)}});
renderer.domElement.addEventListener('pointerdown',e=>{const obj=e.button===0&&!game.running&&game.selected!=='erase'?objectAt(e):null;down={x:e.clientX,y:e.clientY,az:azimuth,el:elevation,tx:target.x,tz:target.z,shift:e.shiftKey,button:e.button,obj:obj&&!e.shiftKey?obj:null};dragObj=null;clearDragPreview();renderer.domElement.setPointerCapture(e.pointerId)});
renderer.domElement.addEventListener('pointermove',e=>{
 if(!down){const obj=objectAt(e);if(obj)showHandle(obj);else if(!overRotateHandle&&!nearRotateHandle(e))showHandle(null);return}
 let dx=e.clientX-down.x,dy=e.clientY-down.y;
 if(down.obj){if(Math.hypot(dx,dy)>7){const c=hit(e);if(c){dragObj={...down.obj,nx:c.x,ny:c.y};updateDragPreview(dragObj);handle.style.display='none';tip.textContent='Отпустите, чтобы переместить · Esc — отмена';tip.style.display='block';tip.style.left=Math.max(5,e.offsetX-90)+'px';tip.style.top=Math.max(5,e.offsetY-55)+'px'}}return}
 if(down.shift||down.button===1){let k=ortho/Math.max(250,mount.clientHeight);target.x=down.tx-dx*k*2;target.z=down.tz+dy*k*2}else{azimuth=down.az-dx*.008;elevation=THREE.MathUtils.clamp(down.el+dy*.006,.18,1.46)}
});
renderer.domElement.addEventListener('pointerup',e=>{if(!down)return;let moved=Math.hypot(e.clientX-down.x,e.clientY-down.y);if(down.obj){if(dragObj){previewValid(dragObj)&&game.moveObject(dragObj.x,dragObj.y,dragObj.nx,dragObj.ny)}else showHandle(down.obj)}else if(moved<7){let cell=hit(e);if(cell&&(game.selected!==null||e.button===2))game.place(cell.x,cell.y,e.button===2)}down=null;dragObj=null;clearDragPreview();tip.textContent='Перетащить · ↻ повернуть'});
renderer.domElement.addEventListener('pointerleave',e=>{if(!down&&!overRotateHandle&&!nearRotateHandle(e))showHandle(null)});
renderer.domElement.addEventListener('contextmenu',e=>e.preventDefault());
renderer.domElement.addEventListener('wheel',e=>{e.preventDefault();ortho=THREE.MathUtils.clamp(ortho*Math.exp(e.deltaY*.001),1.8,25)},{passive:false});
window.addEventListener('keydown',e=>{if(e.target.closest('input,select,textarea'))return;if(e.key==='Escape'){e.preventDefault();down=null;dragObj=null;clearDragPreview();showHandle(null);game.observeMode();return}if((e.ctrlKey||e.metaKey)&&e.key.toLowerCase()==='z'&&!e.shiftKey){if(game.undoEdit())e.preventDefault();return}if(e.key.toLowerCase()==='q')azimuth-=Math.PI/2;if(e.key.toLowerCase()==='e')azimuth+=Math.PI/2});
const clock=new THREE.Clock();function frame(){requestAnimationFrame(frame);let sig=signature();if(sig!==lastSignature){rebuild();lastSignature=sig;if(game.N===22&&ortho<16){ortho=16;cameraUpdate()}}let dt=clock.getDelta();let t=clock.elapsedTime;updatePeople(t,dt);updateLivePosters();refreshEntranceSign();
 if(bouncerAction&&game.running!==bouncerWasRunning){bouncerWasRunning=game.running;if(game.running)bouncerAction.reset().play();else bouncerAction.stop()}
 if(bouncerMixer&&game.running&&!game.paused)bouncerMixer.update(Math.min(dt,.06));
 const targetNight=game.running?1:0;nightMix+=(targetNight-nightMix)*.025;
 ambient.intensity=THREE.MathUtils.lerp(3.0,.52,nightMix);
 sun.intensity=THREE.MathUtils.lerp(3.4,.42,nightMix);
 scene.background.copy(dayColor).lerp(nightColor,nightMix);scene.fog.color.copy(scene.background);
 for(const g of danceGlows){const phase=t*4.8+g.x*.9+g.z*.73;
  g.mesh.material.opacity=game.running&&game.lighting?(game.paused?.16:(.12+.42*Math.pow(Math.max(0,Math.sin(phase)),3)))*nightMix:0;
 }
for(let [i,fx] of lights.entries()){
 const active=game.lighting&&game.running;
 const pulse=game.paused?.55:(.75+.25*Math.sin(t*3.7+i*1.7));
 fx.light.visible=active;fx.spill.visible=active;fx.beam.visible=active;
 fx.light.intensity=active?(fx.type==='laser'?30:fx.type==='light'?34:12)*pulse:0;
 fx.spill.intensity=active?(fx.type==='laser'?6:fx.type==='light'?9:3)*pulse:0;
 fx.beam.material.opacity=active?(fx.type==='laser'?.36:.13)*pulse:0;
 fx.target.position.x=Math.sin(t*(fx.type==='laser'?2.0:.85)+i*1.9)*2.4;
 fx.target.position.z=Math.cos(t*(fx.type==='laser'?1.5:.9)+i)*2.4;
 fx.target.updateMatrixWorld();
 // Cone points toward the same moving target as the spotlight.
 const from=fx.beam.parent.localToWorld(new THREE.Vector3(0,1.65,0));
 const to=fx.target.getWorldPosition(new THREE.Vector3());
 const dir=to.sub(from).normalize();
 fx.beam.quaternion.setFromUnitVectors(new THREE.Vector3(0,-1,0),dir);
}cameraUpdate();if(hovered&&!down)showHandle(hovered);// Artwork stays in the same world coordinate system as the floor when camera orbits.
renderer.render(scene,camera);if(!window.__nightshift3dReady){window.__nightshift3dReady=true;window.dispatchEvent(new Event('nightshift:3d-ready'))}}frame();
window.nightshiftStats=function(){
 const stats={
  gameGuests:game.people.length,threeGuests:peopleMap.size,
  geometries:renderer.info.memory.geometries,textures:renderer.info.memory.textures,
  drawCalls:renderer.info.render.calls,triangles:renderer.info.render.triangles,
  sceneObjects:0,skinnedMeshes:0,animationMixers:0,
  loadedCharacterStates:raverModels.reduce((n,m)=>n+Object.values(m.states).filter(Boolean).length,0),
  jsHeapMB:performance.memory?Math.round(performance.memory.usedJSHeapSize/1048576):'not available'
 };
 scene.traverse(o=>{stats.sceneObjects++;if(o.isSkinnedMesh)stats.skinnedMeshes++});
 for(const o of peopleMap.values())if(o.userData.mixer)stats.animationMixers++;
 console.table(stats);return stats;
};

