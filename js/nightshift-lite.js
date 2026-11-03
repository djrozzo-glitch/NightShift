import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {MeshoptDecoder} from 'three/addons/libs/meshopt_decoder.module.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {clone as cloneSkeleton} from 'three/addons/utils/SkeletonUtils.js';

const $=id=>document.getElementById(id);

const mount=$('scene'), scene=new THREE.Scene();
scene.background=new THREE.Color('#090b16'); scene.fog=new THREE.FogExp2('#0c0b17',.024);
const renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance'});
renderer.toneMapping=THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure=1.3;
// Quality settings apply live, without reloading 3D assets.
let fxQuality=localStorage.getItem('nightshift-fx-quality')||'medium';
if(!['low','medium','high'].includes(fxQuality))fxQuality='medium';
const fxSettings={low:{smoke:10,beams:1,spots:false,brightness:.85},medium:{smoke:24,beams:2,spots:true,brightness:1},high:{smoke:38,beams:3,spots:true,brightness:1.15}};
$('fxQuality').value=fxQuality;
$('fxQuality').addEventListener('change',()=>{
 fxQuality=$('fxQuality').value;
 localStorage.setItem('nightshift-fx-quality',fxQuality);
});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.0));
renderer.outputColorSpace=THREE.SRGBColorSpace;
renderer.shadowMap.enabled=false;
renderer.setSize(mount.clientWidth,mount.clientHeight);
mount.insertBefore(renderer.domElement,mount.firstChild);
const camera=new THREE.PerspectiveCamera(42,mount.clientWidth/mount.clientHeight,.1,100);
camera.position.set(17,17,19);
const controls=new OrbitControls(camera,renderer.domElement);
controls.target.set(0,0,0);controls.enableDamping=true;controls.maxPolarAngle=Math.PI*.46;
controls.minDistance=11;controls.maxDistance=39;controls.update();
const hemi=new THREE.HemisphereLight(0xded7ff,0x191424,2.3);scene.add(hemi);
const sun=new THREE.DirectionalLight(0xffdfba,2);sun.position.set(-10,16,8);scene.add(sun);
const stage=new THREE.Group();scene.add(stage);
// Atmospheric smoke made of camera-facing soft sprites, not opaque horizontal planes.
// Use a single shared texture and lightweight geometry; no heavy post-processing.
const smokeCanvas=document.createElement('canvas');smokeCanvas.width=128;smokeCanvas.height=128;
const smokeCtx=smokeCanvas.getContext('2d');
const smokeGradient=smokeCtx.createRadialGradient(64,64,3,64,64,63);
smokeGradient.addColorStop(0,'rgba(200,190,220,0.45)');
smokeGradient.addColorStop(.3,'rgba(177,169,205,0.25)');
smokeGradient.addColorStop(.65,'rgba(145,140,170,0.09)');
smokeGradient.addColorStop(1,'rgba(125,120,155,0)');
smokeCtx.fillStyle=smokeGradient;smokeCtx.fillRect(0,0,128,128);
const smokeTexture=new THREE.CanvasTexture(smokeCanvas);
const hazeLayers=[];
for(let i=0;i<38;i++){
 const material=new THREE.SpriteMaterial({map:smokeTexture,color:0xc4c0d7,transparent:true,opacity:0,depthWrite:false,blending:THREE.NormalBlending,fog:true});
 const sprite=new THREE.Sprite(material);
 sprite.position.set(-6+Math.random()*12,.65+Math.random()*1.35,-6+Math.random()*12);
 sprite.scale.set(2.4+Math.random()*1.8,1.5+Math.random()*1.5,1);
 scene.add(sprite);hazeLayers.push({mesh:sprite,offset:i*1.73,baseX:sprite.position.x,baseZ:sprite.position.z});
}
const loader=new GLTFLoader();
loader.setMeshoptDecoder(MeshoptDecoder);
const loadGLB=path=>new Promise(resolve=>loader.load(path,resolve,undefined,err=>{console.warn('Optional GLB not loaded',path,err);resolve(null)}));
// Optimized copies live next to original Godot GLBs. The original remains a safe fallback.
const loadVenueModel=async name=>(await loadGLB('assets/models/'+name+'_opt.glb')) || (await loadGLB('godot/assets/models/'+name+'.glb'));
// Optimized assets produced by glTF Transform may use EXT_meshopt_compression.
const mat=(color,roughness=.85)=>new THREE.MeshStandardMaterial({color,roughness});
const concrete=mat(0x252330),dark=mat(0x302c3c),danceMat=mat(0x503463),edgeMat=mat(0x50455a);
function block(w,h,d,x,y,z,material,parent=stage){const o=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),material);o.position.set(x,y,z);parent.add(o);return o;}
// Fixed NightShift venue: clear front opening, modelled wall modules, lounge and equipment.
block(16,.2,16,0,-.15,0,concrete);
for(let x=-7.5;x<=7.5;x++)for(let z=-7.5;z<=7.5;z++){
 block(1,.012,1,x,-.035,z,(Math.round(x+z)&1)?concrete:dark);
}
const wallPieces=[];
for(let i=-7.5;i<=7.5;i++){
 wallPieces.push([i,-7.9,0],[7.9,i,Math.PI/2],[-7.9,i,Math.PI/2]);
 if(Math.abs(i)>.5)wallPieces.push([i,7.9,0]);
}
// Replace placeholder rectangles with optimized floor.glb tiles, keeping a fallback.
const danceTilePositions=[];
for(let x=-3.5;x<=3.5;x++)for(let z=-5.5;z<=.5;z++)danceTilePositions.push([x,z]);
// Lightweight dancefloor color wave: material-only animation, no extra
// lights, meshes, render passes or draw calls. All GLB textures stay shared.
const danceFloorTiles=[];
const danceFloorTint=new THREE.Color();
let danceFloorGlow=0,danceFloorTick=0;
function registerDanceTile(root,x,z){
 const localMaterials=new Map(),materials=[];
 root.traverse(obj=>{
  if(!obj.isMesh||!obj.material)return;
  const unique=source=>{
   if(!source)return source;
   if(!localMaterials.has(source)){
    const copy=source.clone();
    localMaterials.set(source,copy);
    materials.push({material:copy,baseColor:copy.color?.clone(),baseEmissive:copy.emissive?.clone()});
   }
   return localMaterials.get(source);
  };
  obj.material=Array.isArray(obj.material)?obj.material.map(unique):unique(obj.material);
 });
 if(materials.length)danceFloorTiles.push({x,z,materials,phase:x*.68-z*.52});
}
const dancePlaceholders=danceTilePositions.map(([x,z])=>{
 const tile=block(.98,.05,.98,x,.035,z,danceMat);
 registerDanceTile(tile,x,z);
 return tile;
});
function animateDanceFloor(dt,active,time){
 const aim=active?1:0;
 danceFloorGlow+= (aim-danceFloorGlow)*Math.min(1,dt*(active?3.5:4.8));
 danceFloorTick+=dt;
 // Updating colors 20 times/sec is enough for slow, smooth waves.
 if(danceFloorTick<.05)return;
 danceFloorTick=0;
 for(const tile of danceFloorTiles){
  const wave=Math.sin(time*1.35+tile.phase);
  const shimmer=.5+.5*Math.sin(time*2.05-tile.x*.46-tile.z*.67);
  // Continuous palette travel avoids abrupt hue switches between tiles.
  const hue=.70+.20*Math.sin(time*.42+tile.phase*.54);
  danceFloorTint.setHSL(hue,.60,.34);
  const strength=danceFloorGlow*(.035+.045*shimmer+.025*(.5+.5*wave));
  for(const entry of tile.materials){
   const m=entry.material;
   if(entry.baseEmissive){
    // THREE.Color has no addScaledVector (that method belongs to Vector3).
    // Mutate RGB channels directly without allocating objects each frame.
    m.emissive.copy(entry.baseEmissive);
    m.emissive.r+=danceFloorTint.r*strength;
    m.emissive.g+=danceFloorTint.g*strength;
    m.emissive.b+=danceFloorTint.b*strength;
   }else if(entry.baseColor){
    m.color.copy(entry.baseColor).lerp(danceFloorTint,strength*.40);
   }
  }
 }
}

// Tile grid: 1x1 objects sit at half-integers, 2x1 furniture at whole integers.
const decor=[
 ['dj_stand_upgraded',0,-6.5,2,0],
 ['speaker_updated',-3.5,-6.5,.95,0],['speaker_updated',3.5,-6.5,.95,0],
 ['bar_new',-7.25,-4,2,Math.PI/2],['bar_new',7.25,-4,2,-Math.PI/2],
 ['sofa_upgraded',-7.25,5,2,Math.PI/2],['sofa_upgraded',7.25,5,2,-Math.PI/2],
 ['sofa_upgraded',-3,7.25,2,Math.PI],['sofa_upgraded',3,7.25,2,Math.PI],
 // Large plants in the four corner cells.
 ['plant_big',-7.5,-7.5,.95,0],['plant_big',7.5,-7.5,.95,0],
 ['plant_big',-7.5,7.5,.95,0],['plant_big',7.5,7.5,.95,0],
 ['plant2',-7.5,.5,.85,0],['plant2',7.5,.5,.85,0],
 ['plant2',-1.5,-7.5,.85,0],['plant2',1.5,-7.5,.85,0],
 ['laser_new',-4.5,-4.5,.8625,Math.PI/2],['laser_new',4.5,-4.5,.8625,-Math.PI/2],
 ['light',-4.5,-1.5,.8625,Math.PI/2],['light',4.5,-1.5,.8625,-Math.PI/2],
 ['discoball',-4.5,3.5,.9375,0],['discoball',4.5,3.5,.9375,0],
 // Wall posters: two symmetrical on the DJ wall; the side posters are grid aligned.
 ['poster',-5.5,-7.55,.95,0],['poster',5.5,-7.55,.95,0],
 ['poster',-2.5,-7.55,.95,0],['poster',2.5,-7.55,.95,0],
 ['poster',-7.55,-1.5,.95,Math.PI/2],['poster',-7.55,2.5,.95,Math.PI/2],
 ['poster',7.55,-1.5,.95,-Math.PI/2],['poster',7.55,2.5,.95,-Math.PI/2],
 // Entrance is centered on the two open front-wall grid cells.
 ['entrance',0,7.8,2,0],
 // Two side tables flanking the armrests of every two-cell sofa.
 ['table',-7.5,3.5,.72,0],['table',-7.5,6.5,.72,0],
 ['table',7.5,3.5,.72,0],['table',7.5,6.5,.72,0],
 ['table',-4.5,7.5,.72,0],['table',-1.5,7.5,.72,0],
 ['table',1.5,7.5,.72,0],['table',4.5,7.5,.72,0]
];
const loadedModels=new Map();
// Each poster receives a full-face emissive screen, fitted to its GLB face.
const posterScreens=[];
let posterScreenName='',posterScreenLive=false;
function makePosterScreen(holder,bounds){
 const width=Math.max(.24,bounds.max.x-bounds.min.x);
 const height=Math.max(.3,bounds.max.y-bounds.min.y);
 const canvas=document.createElement('canvas');canvas.width=512;canvas.height=1024;
 const ctx=canvas.getContext('2d');
 const texture=new THREE.CanvasTexture(canvas);
 texture.colorSpace=THREE.SRGBColorSpace;
 const material=new THREE.MeshBasicMaterial({map:texture,side:THREE.DoubleSide,toneMapped:false});
 const mesh=new THREE.Mesh(new THREE.PlaneGeometry(width*.965,height*.985),material);
 mesh.position.set((bounds.min.x+bounds.max.x)/2,(bounds.min.y+bounds.max.y)/2,bounds.max.z+.035);
 mesh.renderOrder=3;
 holder.add(mesh);
 const screen={ctx,texture,mesh};posterScreens.push(screen);
 drawPosterScreen(screen,posterScreenName,posterScreenLive);
}
function drawPosterScreen(screen,name,live){
 const ctx=screen.ctx,w=512,h=1024;
 const gradient=ctx.createLinearGradient(0,0,w,h);
 gradient.addColorStop(0,'#160d25');gradient.addColorStop(.55,'#39163e');gradient.addColorStop(1,'#0d1932');
 ctx.fillStyle=gradient;ctx.fillRect(0,0,w,h);
 ctx.fillStyle='#8538a8';ctx.fillRect(18,18,w-36,9);ctx.fillRect(18,h-27,w-36,9);
 ctx.strokeStyle='#ae58d8';ctx.lineWidth=8;ctx.strokeRect(9,9,w-18,h-18);
 ctx.textAlign='center';ctx.textBaseline='middle';
 ctx.fillStyle='#b3a6d5';ctx.font='bold 37px sans-serif';
 ctx.fillText('NIGHT SHIFT',w/2,112,w-60);
 ctx.fillStyle='#f1e0ff';ctx.font='bold 50px sans-serif';
 ctx.fillText(live?'NOW PLAYING':'TONIGHT',w/2,280,w-42);
 const words=String(name||'DJ').toUpperCase().split(/\s+/);
 const lines=[];let line='';
 for(const word of words){
  if((line+' '+word).length>13&&line){lines.push(line);line=word;}
  else line=line?line+' '+word:word;
 }
 if(line)lines.push(line);
 const fontSize=lines.length>2?66:lines.length>1?82:100;
 ctx.font='900 '+fontSize+'px sans-serif';ctx.fillStyle='#b8f9df';
 const start=505-(lines.length-1)*fontSize*.62;
 lines.forEach((part,i)=>ctx.fillText(part,w/2,start+i*fontSize*1.12,w-58));
 ctx.fillStyle='#dbaaf0';ctx.font='bold 32px sans-serif';
 ctx.fillText(live?'● LIVE ON THE DANCEFLOOR':'UNDERGROUND SESSION',w/2,830,w-52);
 screen.texture.needsUpdate=true;
}
function updatePosterScreens(name,live){
 posterScreenName=name||'DJ';posterScreenLive=!!live;
 for(const screen of posterScreens)drawPosterScreen(screen,posterScreenName,posterScreenLive);
}

// Drinks on all eight sofa armrest tables: simple lightweight glassware.
const drinkGlass=new THREE.CylinderGeometry(.065,.045,.16,8);
const drinkMat=new THREE.MeshStandardMaterial({color:0x9cc8d8,transparent:true,opacity:.68,roughness:.2,metalness:.1});
const drinkLiquid=new THREE.MeshStandardMaterial({color:0xd46a84,roughness:.35});
for(const [x,z] of [[-7.5,3.5],[-7.5,6.5],[7.5,3.5],[7.5,6.5],[-4.5,7.5],[-1.5,7.5],[1.5,7.5],[4.5,7.5]]){
 const cup=new THREE.Mesh(drinkGlass,drinkMat);
 cup.position.set(x,.64,z);stage.add(cup);
 const drink=new THREE.Mesh(new THREE.CylinderGeometry(.038,.038,.065,8),drinkLiquid);
 drink.position.set(x,.60,z);stage.add(drink);
}

loadVenueModel('floor').then(g=>{
 if(!g)return;
 const source=g.scene;
 fitModel(source,.98);
 dancePlaceholders.forEach(p=>stage.remove(p));
 // Fallback tile materials were dedicated copies. Dispose only these,
 // never the shared GLB geometry, textures or source materials.
 for(const tile of danceFloorTiles)for(const entry of tile.materials)entry.material.dispose();
 danceFloorTiles.length=0;
 for(const [x,z] of danceTilePositions){
  const tile=source.clone(true);
  registerDanceTile(tile,x,z);
  const holder=new THREE.Group();holder.position.set(x,.045,z);holder.add(tile);stage.add(holder);
 }
});
function fitCharacterHeight(root,height=1.65){
 root.updateMatrixWorld(true);
 let box=new THREE.Box3().setFromObject(root);
 if(box.isEmpty())return;
 root.scale.multiplyScalar(height/Math.max(box.max.y-box.min.y,.001));
 root.updateMatrixWorld(true);box=new THREE.Box3().setFromObject(root);
 const center=new THREE.Vector3();box.getCenter(center);
 root.position.x-=center.x;root.position.z-=center.z;root.position.y-=box.min.y;
}

function fitModel(root,size){root.updateMatrixWorld(true);let box=new THREE.Box3().setFromObject(root);
if(box.isEmpty())return;const ext=new THREE.Vector3();box.getSize(ext);
root.scale.multiplyScalar(size/Math.max(ext.x,ext.z,.001));
root.updateMatrixWorld(true);box=new THREE.Box3().setFromObject(root);
const mid=new THREE.Vector3();box.getCenter(mid);
root.position.x-=mid.x;root.position.z-=mid.z;root.position.y-=box.min.y;
}
let ready3d=false;
const fixtures=[];
const beamStart=new THREE.Vector3(),beamEnd=new THREE.Vector3(),beamDirection=new THREE.Vector3(),upVector=new THREE.Vector3(0,1,0);
const beamMid=new THREE.Vector3();
const beamGeoLaser=new THREE.CylinderGeometry(.12,.02,1,16,1,true);
const beamGeoWash=new THREE.CylinderGeometry(.56,.07,1,20,1,true);
const haloGeoLaser=new THREE.CylinderGeometry(.22,.04,1,16,1,true);
const haloGeoWash=new THREE.CylinderGeometry(.85,.08,1,20,1,true);
function makeAtmosBeam(color,laser){
 const material=new THREE.MeshBasicMaterial({
  color,transparent:true,opacity:0,depthWrite:false,
  side:THREE.DoubleSide,blending:THREE.AdditiveBlending,
  fog:true
 });
 const haloMaterial=material.clone();haloMaterial.opacity=0;
 const mesh=new THREE.Mesh(laser?beamGeoLaser:beamGeoWash,material);
 const halo=new THREE.Mesh(laser?haloGeoLaser:haloGeoWash,haloMaterial);
 for(const obj of [mesh,halo]){obj.frustumCulled=false;obj.renderOrder=2;stage.add(obj);}
 return {mesh,halo};
}
function addFixture(holder,obj,name){
 obj.updateMatrixWorld(true);
 const bounds=new THREE.Box3().setFromObject(obj);
 const top=Math.max(.4,bounds.max.y-holder.position.y);
 if(name==='discoball'){
  // One instanced mesh per mirror ball, instead of dozens of draw calls.
  // Dots spill onto the floor AND the surrounding walls, like real mirror
  // reflections moving with the ball.
  const geometry=new THREE.CircleGeometry(1,10);
  const material=new THREE.MeshBasicMaterial({
   map:smokeTexture,color:0xffffff,transparent:true,opacity:0,
   depthWrite:false,side:THREE.DoubleSide,
   blending:THREE.AdditiveBlending,toneMapped:false
  });
  const reflections=new THREE.InstancedMesh(geometry,material,90);
  reflections.instanceMatrix.setUsage(THREE.DynamicDrawUsage);
  reflections.frustumCulled=false;
  reflections.renderOrder=2;
  for(let i=0;i<90;i++){
   const color=new THREE.Color();
   color.setHSL(.58+(i%7)*.034,.20+(i%3)*.06,.64+(i%5)*.04);
   reflections.setColorAt(i,color);
  }
  stage.add(reflections);
  const glow=new THREE.PointLight(0xcbb9ff,0,8,2);
  glow.position.y=top-.06;holder.add(glow);
  fixtures.push({name,holder,obj,reflections,glow,top,phase:holder.position.x>0?1.7:0});
 }else if(name==='laser_new'||name==='light'){
  const laser=name==='laser_new';
  const colors=laser?[0x31ff64,0x287cff,0xff334d]:[0xc15dff,0x87abff];
  const beams=colors.map(color=>makeAtmosBeam(color,laser));
  const lamp=new THREE.PointLight(colors[0],0,6,2);
  lamp.position.y=top-.1;holder.add(lamp);
  // One real spotlight per fixture creates light on surfaces and dancers,
  // while the transparent meshes make the haze beam visible.
  const spot=new THREE.SpotLight(colors[0],0,14,laser?.26:.46,.64,1.4);
  spot.position.set(holder.position.x,top,holder.position.z);
  const target=new THREE.Object3D();scene.add(target);
  spot.target=target;scene.add(spot);
  fixtures.push({name,holder,top,beams,lamp,spot,target,laser});
 }
}
function animateFixtures(t,dt,active){
 const quality=fxSettings[fxQuality];
 for(const fx of fixtures){
  if(fx.name==='discoball'){
   if(active)fx.obj.rotation.y+=dt*.58;
   fx.glow.intensity=active?(1.15+.26*Math.sin(t*3.4+fx.phase))*quality.brightness:0;
   const count=fxQuality==='low'?30:fxQuality==='medium'?60:90;
   fx.reflections.count=active?count:0;
   fx.reflections.material.opacity=active?.62*quality.brightness:0;
   const dummy=new THREE.Object3D();
   for(let i=0;i<count;i++){
    const theta=i*2.39996323+t*.38+fx.phase;
    const drift=Math.sin(t*.27+i*.79);
    const r=1.15+(i%13)*.37;
    const x=fx.holder.position.x+Math.cos(theta)*r;
    const z=fx.holder.position.z+Math.sin(theta)*r;
    const size=(.075+(i%5)*.018)*(.84+.16*Math.sin(t*2+i));
    dummy.rotation.set(0,0,0);
    if(i%9===0){
     // Reflections on the rear wall.
     dummy.position.set(THREE.MathUtils.clamp(x,-7.5,7.5),.35+(i%12)*.13,-7.78);
    }else if(i%7===0){
     // Reflections on the side wall facing the club.
     const side=fx.holder.position.x<0?-1:1;
     dummy.position.set(side*7.76,.3+(i%11)*.14,THREE.MathUtils.clamp(z,-7.4,7.4));
     dummy.rotation.y=side===-1?Math.PI/2:-Math.PI/2;
    }else{
     dummy.position.set(THREE.MathUtils.clamp(x+drift*.1,-7.55,7.55),.063,THREE.MathUtils.clamp(z,-7.55,7.55));
     dummy.rotation.x=-Math.PI/2;
    }
    dummy.scale.set(size,size,1);
    dummy.updateMatrix();
    fx.reflections.setMatrixAt(i,dummy.matrix);
   }
   fx.reflections.instanceMatrix.needsUpdate=true;
   continue;
  }
  // Alternating fan/sweep patterns: smooth scanning, no hard jumps.
  const phase=t*.57+fx.holder.position.x*.8;
  const pulse=.78+.22*Math.sin(t*2.9+fx.holder.position.z);
  fx.lamp.intensity=active?2.5*pulse*quality.brightness:0;
  fx.lamp.getWorldPosition(beamStart);
  fx.beams.forEach((part,i)=>{
   const visible=active&&i<quality.beams;
   const a=phase+i*(fx.laser?.46:.9);
   const sweep=fx.laser?2.8:3.4;
   beamEnd.set(Math.sin(a)*sweep,.12,-2.55+Math.cos(a*.68+i*.35)*2.25);
   beamDirection.copy(beamEnd).sub(beamStart);
   const length=beamDirection.length();
   beamDirection.normalize();
   beamMid.copy(beamStart).addScaledVector(beamDirection,length*.5);
   const rotation=new THREE.Quaternion().setFromUnitVectors(upVector,beamDirection);
   const opacity=(fx.laser?.24:.13)*pulse*quality.brightness;
   for(const [obj,scale,alpha] of [[part.mesh,1,opacity],[part.halo,1,opacity*.24]]){
    obj.position.copy(beamMid);
    obj.quaternion.copy(rotation);
    obj.scale.set(scale,length,scale);
    obj.material.opacity=visible?alpha:0;
    obj.visible=visible;
   }
   if(i===0){
    fx.target.position.copy(beamEnd);
    fx.spot.position.copy(beamStart);
    fx.spot.intensity=visible&&quality.spots?(fx.laser?11:14)*pulse*quality.brightness:0;
   }
  });
 }
}
Promise.all(decor.map(async([name,x,z,size,rotation])=>{
 const gltf=await loadVenueModel(name);
 if(!gltf)return;
 const holder=new THREE.Group(),obj=gltf.scene;
 fitModel(obj,size);
// Capture local bounds before rotating the poster holder; this guarantees
// the screen faces into the venue on all three walls.
const posterBounds=name==='poster'?new THREE.Box3().setFromObject(obj):null;
holder.position.set(x,.04,z);holder.rotation.y=rotation||0;holder.add(obj);stage.add(holder);loadedModels.set(name,holder);
 if(posterBounds)makePosterScreen(holder,posterBounds);
 if(['discoball','laser_new','light'].includes(name))addFixture(holder,obj,name);
})).then(()=>{ready3d=true;$('loading').textContent='Клуб готов.';});
const wallLoad=loadVenueModel('wall').then(g=>{
 for(const [x,z,rotation] of wallPieces){
  if(!g){block(1,1.55,.22,x,.7,z,dark);continue}
  const holder=new THREE.Group(),obj=g.scene.clone(true);fitModel(obj,.99);
  holder.position.set(x,.02,z);holder.rotation.y=rotation;holder.add(obj);stage.add(holder);
 }
});
const djActors={};
const peopleExtras=Promise.all([
 loadGLB('assets/characters/bouncer.glb'),
 loadGLB('assets/characters/deejay_idle.glb'),
 loadGLB('assets/characters/deejay_handdsup.glb'),
 loadGLB('assets/characters/deejay_standing.glb')
]).then(([bouncer,idle,handsup,standing])=>{
 const bouncerRoot=new THREE.Group();bouncerRoot.position.set(1.5,.04,8.5);
 if(bouncer){const actor=bouncer.scene;fitCharacterHeight(actor,1.65);bouncerRoot.add(actor);if(bouncer.animations?.length){const mixer=new THREE.AnimationMixer(actor);mixer.clipAction(bouncer.animations[0]).play();extraMixers.push(mixer);}}
 stage.add(bouncerRoot);
 const djRoot=new THREE.Group();djRoot.position.set(0,.06,-7.5);djRoot.rotation.y=0;
 stage.add(djRoot);
 for(const [state,asset] of [['idle',idle||standing],['standing',standing||idle],['party',handsup||standing||idle]]){
  if(!asset)continue;
  const actor=cloneSkeleton(asset.scene);fitCharacterHeight(actor,1.65);
  actor.visible=state==='idle';djRoot.add(actor);djActors[state]=actor;
  if(asset.animations?.length){const mixer=new THREE.AnimationMixer(actor);mixer.clipAction(asset.animations[0]).play();extraMixers.push(mixer);}
 }
});
const extraMixers=[];
function makeTextPanel(text,w,h,{fontSize=68,background='#130c22',foreground='#e5c6ff'}={}){
 const canvas=document.createElement('canvas');canvas.width=1024;canvas.height=256;
 const ctx=canvas.getContext('2d');ctx.fillStyle=background;ctx.fillRect(0,0,1024,256);
 ctx.strokeStyle='#a657dd';ctx.lineWidth=18;ctx.strokeRect(9,9,1006,238);
 ctx.fillStyle=foreground;ctx.font='800 '+fontSize+'px sans-serif';ctx.textAlign='center';ctx.textBaseline='middle';
 ctx.fillText(text,512,128,950);
 const texture=new THREE.CanvasTexture(canvas);texture.colorSpace=THREE.SRGBColorSpace;
 const mesh=new THREE.Mesh(new THREE.PlaneGeometry(w,h),new THREE.MeshBasicMaterial({map:texture,side:THREE.DoubleSide}));
 return {mesh,texture,ctx,canvas};
}
const sign=makeTextPanel('NIGHT SHIFT',2.8,.72,{fontSize:86});
sign.mesh.position.set(0,2.0,8.05);stage.add(sign.mesh);
// A second sign faces INTO the venue; mirrored orientation makes the lettering readable from the dancefloor.
const insideSign=makeTextPanel('NIGHT SHIFT',2.8,.72,{fontSize:86});
insideSign.mesh.position.set(0,2.0,7.64);
insideSign.mesh.rotation.y=Math.PI;
stage.add(insideSign.mesh);
let clubName=localStorage.getItem('nightshift-lite-club')||'ABLETON GYM';
function updateClubName(){
 for(const panel of [sign,insideSign]){
  panel.ctx.fillStyle='#130c22';panel.ctx.fillRect(0,0,1024,256);
  panel.ctx.strokeStyle='#a657dd';panel.ctx.lineWidth=18;panel.ctx.strokeRect(9,9,1006,238);
  panel.ctx.fillStyle='#8bffc9';panel.ctx.font='800 84px sans-serif';
  panel.ctx.textAlign='center';panel.ctx.textBaseline='middle';
  panel.ctx.fillText(clubName.toUpperCase(),512,128,950);
  panel.texture.needsUpdate=true;
 }
 $('clubName').value=clubName;
}
$('saveClubName').onclick=()=>{const next=$('clubName').value.trim().slice(0,32);if(!next)return;clubName=next;localStorage.setItem('nightshift-lite-club',clubName);updateClubName();};
updateClubName();

const beams=[new THREE.PointLight(0xdd39ff,0,13,2),new THREE.PointLight(0x377dff,0,12,2)];
beams[0].position.set(-4,3,-3);beams[1].position.set(4,3,-4);beams.forEach(l=>scene.add(l));
// Indirect venue lighting keeps the 3D furniture and guests readable at night.
const venueFills=[
 new THREE.PointLight(0xbdb4e8,0,15,2),
 new THREE.PointLight(0x8ac4d9,0,13,2),
 new THREE.PointLight(0xd4a0b9,0,13,2),
 new THREE.PointLight(0xaba5d6,0,12,2)
];
[[-3,3,-2],[3,3,-2],[-4,2.7,4],[4,2.7,4]].forEach(([x,y,z],i)=>{
 venueFills[i].position.set(x,y,z);scene.add(venueFills[i]);
});
// Gentle washes near the walls help separate the crowd from furniture.
const wallWashes=[
 new THREE.PointLight(0x9656bb,0,6.5,2),
 new THREE.PointLight(0x448cba,0,6.5,2),
 new THREE.PointLight(0x9656bb,0,6.5,2),
 new THREE.PointLight(0x448cba,0,6.5,2)
];
[[-7,2,-3],[7,2,-3],[-7,2,3],[7,2,3]].forEach(([x,y,z],i)=>{
 wallWashes[i].position.set(x,y,z);scene.add(wallWashes[i]);
});
// Local lineup is used ONLY when the Google Sheet cannot be read.
// A successful sheet load replaces names, styles, SoundCloud URLs and fees.
const fallbackArtists=[
 {id:'rozzo',name:'rozzo',genre:'Deep Tech',url:'https://soundcloud.com/irozov/rozzo-waste-my-time-i-dont-1'},
 {id:'neonexus',name:'Neonexus',genre:'Hypnotic Techno',url:'https://soundcloud.com/amn303/backdoor-radio-mix-neonexus'},
 {id:'vanya',name:'Vanya Velin',genre:'Raw Techno',url:'https://soundcloud.com/bcco/bcco-premiere-vanya-velin'},
 {id:'lutanina',name:'Lutanina',genre:'Soulful Techno',url:'https://soundcloud.com/user-880945103/two-rndm-06-02'},
 {id:'zlostniy',name:'zlostniy',genre:'Romantic Techno',url:'https://soundcloud.com/velvet-37/shine-ft-zlostniy'},
 {id:'lowq',name:'lowQ',genre:'Jungle',url:'https://soundcloud.com/shiftedrecordings/waves-of-light-1'},
 {id:'velvet37',name:'Velvet 37',genre:'Future Garage',url:'https://soundcloud.com/velvet-37/my-angel-1'},
 {id:'raison',name:'Raison',genre:'Minimal Techno',url:'https://soundcloud.com/raison_d_etre/even-sexier-groove'},
 {id:'boriskhodok',name:'DJ Boris Khodok',genre:'Deep House',url:'https://soundcloud.com/dj-boris-khodok/8-march-mix'}
];
let artists=fallbackArtists.map(a=>({...a}));
let nameToLabel=Object.fromEntries(artists.map(a=>[a.id,a.name]));
let tracks=Object.fromEntries(artists.map(a=>[a.id,a.url]));
function currentArtist(){return artists.find(a=>a.id===$('dj').value)||artists[0];}
function renderLineup(){
 const select=$('dj'),selected=select.value;
 select.replaceChildren();
 for(const a of artists){
  const option=document.createElement('option');
  option.value=a.id;
  option.textContent=a.name+(a.genre?' · '+a.genre:'');
  select.appendChild(option);
 }
 select.value=artists.some(a=>a.id===selected)?selected:artists[0]?.id||'';
 nameToLabel=Object.fromEntries(artists.map(a=>[a.id,a.name]));
 tracks=Object.fromEntries(artists.map(a=>[a.id,a.url]));
 updatePosterScreens(nameToLabel[select.value]||'DJ',false);
}
renderLineup();
let playerVolume=Math.max(0,Math.min(100,Number(localStorage.getItem('nightshift-sc-volume')??75)||0));
$('musicVolume').value=String(playerVolume);
$('musicVolumeValue').textContent=playerVolume+'%';
function setMusicVolume(nextValue){
 playerVolume=Math.max(0,Math.min(100,Number(nextValue)||0));
 $('musicVolume').value=String(playerVolume);
 $('musicVolumeValue').textContent=playerVolume+'%';
 localStorage.setItem('nightshift-sc-volume',String(playerVolume));
 if(scWidget)scWidget.setVolume(playerVolume);
}
$('musicVolume').addEventListener('input',event=>setMusicVolume(event.target.value));
let scWidget=null,scReady=false,scRequested=false,scStarted=false;
const musicStatus=$('musicStatus');
function syncTrack(){
 const artist=currentArtist();
 updatePosterScreens(artist?.name||'DJ',false);
 const url=artist?.url||'';
 $('trackLink').href=url||'https://soundcloud.com';
 $('trackLink').textContent=url?'♫ '+artist.name+' — открыть SoundCloud':'Для '+(artist?.name||'DJ')+' нет ссылки SoundCloud';
 scReady=false;scStarted=false;scRequested=false;
 if(!url){
  $('play').disabled=true;
  musicStatus.textContent='У выбранного DJ нет ссылки на трек. Проверь Google Sheets.';
  return;
 }
 if(scWidget){
  scWidget.load(url,{auto_play:false,show_comments:false,show_user:true,show_reposts:false,visual:false});
 }else{
  $('scFrame').src='https://w.soundcloud.com/player/?url='+encodeURIComponent(url)+'&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&visual=false';
 }
 if($('curtain').style.display==='none'&&$('end').disabled)$('play').disabled=false;
 musicStatus.textContent='Трек готовится к воспроизведению. Нажми «Начать вечеринку».';
}
function initSoundCloud(){
 if(!window.SC?.Widget){
  musicStatus.textContent='SoundCloud API недоступен. Запусти музыку вручную в плеере.';
  return;
 }
 scWidget=window.SC.Widget($('scFrame'));
 const E=window.SC.Widget.Events;
 scWidget.bind(E.READY,()=>{
  scReady=true;
  scWidget.setVolume(playerVolume);
  if(scRequested&&running&&!paused&&!ending)scWidget.play();
 });
 scWidget.bind(E.PLAY,()=>{
  if(paused||ending){scWidget.pause();return;}
  scWidget.setVolume(playerVolume);
  scStarted=true;
  musicStatus.textContent='♫ Играет '+nameToLabel[$('dj').value]+'. Вечеринка закончится вместе с треком.';
 });
 scWidget.bind(E.FINISH,()=>{
  if(running&&scStarted)endParty('Трек закончился. Вечеринка завершена.');
 });
 scWidget.bind(E.ERROR,()=>{
  if(running)musicStatus.textContent='Не удалось воспроизвести трек. Проверь SoundCloud или включи его вручную.';
 });
}
$('dj').addEventListener('change',()=>{updateFee();syncTrack()});
syncTrack();
initSoundCloud();
let fees={};
let guestCapacity=20;
const MIN_GUESTS=20;
function getGuestCapacity(id=$('dj').value){
 const values=Object.values(fees).filter(Number.isFinite);
 if(!Number.isFinite(fees[id])||values.length<2)return MIN_GUESTS;
 const min=Math.min(...values),max=Math.max(...values);
 if(max<=min)return MIN_GUESTS;
 return Math.max(MIN_GUESTS,Math.min(MAX_GUESTS,Math.round(MIN_GUESTS+(fees[id]-min)/(max-min)*(MAX_GUESTS-MIN_GUESTS))));
}
function refreshBooking(){
 const fee=fees[$('dj').value];
 guestCapacity=getGuestCapacity();
 $('fee').textContent=Number.isFinite(fee)?'€'+new Intl.NumberFormat('nl-NL',{maximumFractionDigits:2}).format(fee):'—';
 $('bookingGuests').textContent=Number.isFinite(fee)?guestCapacity+' / '+MAX_GUESTS:'20 / '+MAX_GUESTS+' (ожидаем Google Sheets)';
 $('counter').textContent='GUESTS: '+guests.length+' / '+guestCapacity;
}

function csvRows(s){const rows=[];let row=[],field='',quote=false;for(let i=0;i<s.length;i++){const c=s[i];if(c==='"'){if(quote&&s[i+1]==='"'){field+='"';i++}else quote=!quote}else if(c===','&&!quote){row.push(field);field=''}else if((c==='\n'||c==='\r')&&!quote){if(c==='\r'&&s[i+1]==='\n')i++;row.push(field);if(row.some(v=>v.trim()))rows.push(row);row=[];field=''}else field+=c}row.push(field);if(row.some(v=>v.trim()))rows.push(row);return rows}
function updateFee(){refreshBooking();}
// Public Google Sheet is the source of truth for the DJ catalogue.
// Accept the shared /edit link, published /pub CSV, or the gviz CSV endpoint.
function sheetCsvUrl(input){
 const value=input.trim();
 const match=value.match(/^https:\/\/docs\.google\.com\/spreadsheets\/d\/([a-zA-Z0-9_-]+)/);
 if(match){
  const gid=value.match(/[?&#]gid=(\d+)/)?.[1];
  return 'https://docs.google.com/spreadsheets/d/'+match[1]+'/gviz/tq?tqx=out%3Acsv'+(gid?'&gid='+gid:'');
 }
 if(/^https:\/\/docs\.google\.com\/spreadsheets\/d\/e\//.test(value))return value;
 throw Error('Нужна ссылка Google Sheets.');
}
function normalizeColumn(value){
 return String(value||'').toLowerCase().replace(/[\s_.\-()\/]+/g,'').replace(/[₽€$]/g,'');
}
function parseSheetArtists(rows){
 if(rows.length<2)throw Error('Таблица пуста.');
 const columns=rows.shift().map(normalizeColumn);
 const column=(aliases)=>columns.findIndex(c=>aliases.some(a=>c===normalizeColumn(a)));
 const idIdx=column(['id','artistid','djid','key','slug','код','ид']);
 const nameIdx=column(['name','dj','djname','artist','artistname','имя','имядиджея','диджей','артист','исполнитель']);
 const genreIdx=column(['genre','style','musicstyle','жанр','стиль','music','направление']);
 const urlIdx=column(['soundcloud','soundcloudurl','soundcloudlink','track','trackurl','tracklink','url','link','ссылка','ссылканатрек','саундклауд','музыка']);
 const feeIdx=column(['fee','booking','bookingfee','price','cost','bookingcost','гонорар','стоимость','ценабукинга','стоимостьбукинга','цена']);
 if(nameIdx<0&&idIdx<0)throw Error('Нужна колонка Name или ID.');
 if(urlIdx<0)throw Error('Нужна колонка SoundCloud или URL.');
 if(feeIdx<0)throw Error('Нужна колонка Fee или Booking.');
 const ids=new Set();
 const result=[];
 for(const row of rows){
  const rawName=String(row[nameIdx]||row[idIdx]||'').trim();
  if(!rawName)continue;
  const rawID=String(row[idIdx]||'').trim().toLowerCase();
  const match=fallbackArtists.find(a=>a.id===rawID||a.name.toLowerCase()===rawName.toLowerCase());
  const id=rawID||match?.id||rawName.toLowerCase().replace(/[^a-z0-9а-яё]+/gi,'-').replace(/^-|-$/g,'');
  if(!id||ids.has(id))continue;
  const url=String(row[urlIdx]||'').trim();
  if(!/^https:\/\/(www\.)?(soundcloud\.com|on\.soundcloud\.com)\//i.test(url)){
   console.warn('Ignoring DJ without a SoundCloud link:',rawName,url);
   continue;
  }
  const feeText=String(row[feeIdx]||'').replace(/\b(?:EUR|EURO|USD|GBP)\b/gi,'').replace(/[€$£\s]/g,'').replace(/\.(?=\d{3}(?:\D|$))/g,'').replace(',','.');
  const fee=Number(feeText);
  if(!Number.isFinite(fee)||fee<0)continue;
  ids.add(id);
  result.push({id,name:rawName,genre:genreIdx>=0?String(row[genreIdx]||'').trim():'',url,fee});
 }
 if(!result.length)throw Error('Не найдено DJ с корректной SoundCloud-ссылкой и гонораром.');
 return result;
}
// Google gviz JSONP works for publicly readable Sheets even when the
// spreadsheet CSV endpoint does not send cross-origin fetch headers.
let sheetRequestCount=0;
function loadSheetJSONP(csvURL){
 return new Promise((resolve,reject)=>{
  const callback='nightshiftSheetResponse_'+(++sheetRequestCount);
  let settled=false;
  const script=document.createElement('script');
  const url=new URL(csvURL);
  url.searchParams.set('tqx','out:json;responseHandler:'+callback);
  const cleanup=()=>{
   delete window[callback];
   script.remove();
   clearTimeout(timeout);
  };
  const finish=(error,rows)=>{
   if(settled)return;
   settled=true;cleanup();
   if(error)reject(error);else resolve(rows);
  };
  window[callback]=(result)=>{
   if(result?.status==='error'){
    const message=result.errors?.map(e=>e.detailed_message||e.message).join('; ')||'Google Sheets отказал в доступе';
    finish(Error(message));return;
   }
   const table=result?.table;
   if(!table?.cols||!table?.rows){finish(Error('Google Sheets вернул неожиданный формат данных.'));return;}
   const heading=table.cols.map(c=>c.label||c.id||'');
   const rows=table.rows.map(r=>(r.c||[]).map(c=>c?.f??c?.v??''));
   finish(null,[heading,...rows]);
  };
  script.onerror=()=>finish(Error('Google Sheets JSONP недоступен. Проверь доступ Viewer и URL.'));
  const timeout=setTimeout(()=>finish(Error('Google Sheets не ответил за 12 секунд.')),12000);
  script.src=url.toString();
  document.head.appendChild(script);
 });
}
async function loadSheet(){
 const input=$('sheet').value.trim();
 $('sheetStatus').textContent='Загружаю DJ из Google Sheets…';
 try{
  const csvURL=sheetCsvUrl(input);
  let rows;
  try{
   const response=await fetch(csvURL,{cache:'no-store'});
   if(!response.ok)throw Error('HTTP '+response.status);
   const body=(await response.text()).replace(/^\uFEFF/,'');
   if(/^\s*<!doctype|^\s*<html/i.test(body))throw Error('Google Sheets вернул HTML вместо CSV.');
   rows=csvRows(body);
  }catch(csvError){
   console.info('NightShift: CSV unavailable, trying Google Visualization JSONP:',csvError);
   rows=await loadSheetJSONP(csvURL);
  }
  const entries=parseSheetArtists(rows);
  if(running||ending)throw Error('Обновление доступно после окончания вечеринки.');
  artists=entries;
  fees=Object.fromEntries(entries.map(a=>[a.id,a.fee]));
  localStorage.setItem('nightshift-lite-sheet',input);
  localStorage.setItem('nightshift-lite-artists',JSON.stringify(entries));
  renderLineup();
  updateFee();
  syncTrack();
  $('sheetStatus').textContent='Синхронизировано DJ: '+entries.length+' · имена, жанры, SoundCloud и гонорары.';
 }catch(error){
  $('sheetStatus').textContent='Google Sheets: '+error.message+' Используется последний доступный список.';
  console.warn('NightShift sheet sync:',error);
 }
}
$('loadSheet').onclick=loadSheet;
const defaultSheet='https://docs.google.com/spreadsheets/d/1vfeH9qxnX1HcEv_BhwrJGI2qjWHQyDVENAFAzgDaqQ8/edit?usp=sharing';
const saved=localStorage.getItem('nightshift-lite-sheet');
$('sheet').value=saved||defaultSheet;
// Defer cache hydration until gameplay constants and guest arrays exist.
Promise.resolve().then(()=>{
 try{
  const cached=JSON.parse(localStorage.getItem('nightshift-lite-artists')||'null');
  if(Array.isArray(cached)&&cached.length&&cached.every(a=>a&&a.id&&a.name&&a.url&&Number.isFinite(a.fee))){
   artists=cached;
   fees=Object.fromEntries(cached.map(a=>[a.id,a.fee]));
   renderLineup();
   updateFee();
   syncTrack();
  }
 }catch(error){console.warn('Cannot read cached DJ lineup:',error);}
 loadSheet();
});
const variants=['baggy_m','fashion_f','jungle_f','raver_f','raver_m'];
const actorAssets={};
let loaded=0;
let actorPromise=null;
let guestsReady=false;
// Service animations are loaded only when the first party begins, keeping startup light.
const guestAnimationFiles={
 baggy_m:{walk:'baggy_m_walk.glb',dance:'baggy_m_dance.glb',idle:'baggy_m_idle.glb',drink:'baggy_m_drink.glb',sit:'baggy_m_sit.glb'},
 fashion_f:{walk:'fashion_f_walk.glb',dance:'fashion_f_dance.glb',idle:'fashion_f_idle.glb',drink:'fashion_f_drink.glb',sit:'fashion_f_sit.glb'},
 jungle_f:{walk:'jungle_f_walk.glb',dance:'jungle_f_dance.glb',idle:'jungle_f_idle.glb',drink:'jungle_f_drink.glb',sit:'jungle_f_sit.glb'},
 raver_f:{walk:'raver_f_walk.glb',dance:'raver_f_dance.glb',idle:'raver_f_chat.glb',drink:'raver_f_chat.glb',sit:'raver_f_sit.glb'},
 raver_m:{walk:'raver_m_walk.glb',dance:'raver_m_dance.glb',idle:'raver_m_idle.glb',drink:'raver_m_drink.glb',sit:'raver_m_sit 2.glb'}
};
// Progressive loading: walking + dancing are playable first. Only ready
// variants can spawn; no guest ever walks invisibly while GLBs are downloading.
const readyGuestVariants=new Set();
let coreGuestPromise=null;
function guestVariantReady(i){
 return !!(actorAssets[i]?.walk?.animations?.length && actorAssets[i]?.dance?.animations?.length);
}
function startGuestPreload(){
 if(actorPromise)return coreGuestPromise;
 const loadAction=async(i,state)=>{
  const name=variants[i],file=guestAnimationFiles[name][state];
  const gltf=await loadGLB('assets/characters/'+encodeURIComponent(file));
  if(!actorAssets[i])actorAssets[i]={};
  if(gltf)actorAssets[i][state]=gltf;
  loaded++;
  return gltf;
 };
 // Stage one: all types can walk into the club and start dancing.
 const core=variants.map((name,i)=>Promise.all([
  loadAction(i,'walk'),loadAction(i,'dance')
 ]).then(()=>{
  if(!guestVariantReady(i))return;
  readyGuestVariants.add(i);
  if(running&&!paused&&!ending&&!guestsReady){
   guestsReady=true;guestClock=0;
   $('stageStatus').textContent='Вечеринка идёт · '+nameToLabel[$('dj').value]+' за пультом. Ожидается до '+guestCapacity+' гостей.';
   addGuest();
  }
 }));
 coreGuestPromise=Promise.all(core);
 // Stage two: idle first (pause/chat), then bar and sofa actions.
 // Starting only after core avoids 25 simultaneous 7–8MB downloads.
 const extras=coreGuestPromise.then(async()=>{
  await Promise.all(variants.map((name,i)=>loadAction(i,'idle')));
  await Promise.all(variants.flatMap((name,i)=>['drink','sit'].map(state=>loadAction(i,state))));
 });
 actorPromise=Promise.all([coreGuestPromise,extras]).then(()=>true);
 return coreGuestPromise;
}
function loadGuestsOnDemand(){return startGuestPreload();}
// GLTF assets remain alive unless the shared geometry/textures are disposed.
// Only call this after ALL guests have left: their animated clones reuse these assets.
function releaseGuestAssets(){
 const geometries=new Set(),materials=new Set(),textures=new Set();
 const captureTexture=value=>{
  if(value?.isTexture)textures.add(value);
  else if(Array.isArray(value))value.forEach(captureTexture);
 };
 for(const assets of Object.values(actorAssets)){
  for(const gltf of Object.values(assets)){
   gltf.scene?.traverse(obj=>{
    if(obj.geometry)geometries.add(obj.geometry);
    const mats=Array.isArray(obj.material)?obj.material:[obj.material];
    for(const material of mats){
     if(!material)continue;
     materials.add(material);
     for(const value of Object.values(material))captureTexture(value);
    }
   });
  }
 }
 geometries.forEach(g=>g.dispose());
 materials.forEach(m=>m.dispose());
 textures.forEach(t=>t.dispose());
 for(const key of Object.keys(actorAssets))delete actorAssets[key];
 readyGuestVariants.clear();
 coreGuestPromise=null;
 actorPromise=null;
 loaded=0;
 console.info('NightShift: guest GLBs, geometry, materials and textures released after the party.');
}
const MAX_GUESTS=40;
let opened=false,running=false,paused=false,ending=false,guestClock=0,partyTime=0;
const guests=[];const clock=new THREE.Clock();
const pick=arr=>arr[Math.floor(Math.random()*arr.length)];
const barSpots=[{x:-6.4,z:-4},{x:6.4,z:-4}];
const sofaSpots=[{x:-6.4,z:5},{x:6.4,z:5},{x:-3,z:6.65-1/3},{x:3,z:6.65-1/3}];
// Quiet conversation spots in the open area between the floor and the lounge.
const chatStations=[
 [{x:-3.5,z:2.5},{x:-2.5,z:2.5}],
 [{x:2.5,z:2.5},{x:3.5,z:2.5}],
 [{x:-2,z:4.5},{x:-1,z:4.5}],
 [{x:1,z:4.5},{x:2,z:4.5}]
];
let chatClock=0;
// Reserve destinations while a guest is walking there AND while they use them.
// A dance tile is never assigned to two guests simultaneously.
const danceSpots=danceTilePositions.map(([x,z])=>({x,z}));
const reservedSpots=new Map();
const spotKey=(activity,spot)=>activity+':'+spot.x+','+spot.z;
function releaseSpot(p){
 if(p.reservation&&reservedSpots.get(p.reservation)===p)reservedSpots.delete(p.reservation);
 p.reservation=null;
}
function reserveDestination(p,activity,preferredSpot=null){
 const candidates=activity==='dance'?danceSpots:activity==='bar'?barSpots:activity==='chat'?chatStations.flat():sofaSpots;
 // Shuffle by starting at a random index, without sorting the shared list.
 const start=preferredSpot?0:Math.floor(Math.random()*candidates.length);
 const choices=preferredSpot?[preferredSpot]:candidates;
 for(let i=0;i<choices.length;i++){
  const spot=choices[(start+i)%choices.length];
  const key=spotKey(activity,spot);
  if(!reservedSpots.has(key)){
   reservedSpots.set(key,p);p.reservation=key;
   return spot;
  }
 }
 return null;
}
const DANCE_FLOOR_Y=.23;
const REGULAR_FLOOR_Y=.05;
function updateGuestElevation(p,dt){
 // Imported dance-floor GLB sits higher than the checkerboard base.
 const x=p.group.position.x,z=p.group.position.z;
 const onDanceFloor=x>=-3.95&&x<=3.95&&z>=-5.95&&z<=.95;
 const target=onDanceFloor?DANCE_FLOOR_Y:REGULAR_FLOOR_Y;
 p.group.position.y+= (target-p.group.position.y)*Math.min(1,dt*9);
}
// Keep the logic state separate from the visible animation.
// Each avatar keeps one cached, independently skinned model per action, so
// neither GLTF skeletons nor materials are shared across guests.
function setAvatarOpacity(item,value){
 if(!item)return;
 for(const entry of item.materials){
  entry.material.opacity=entry.opacity*value;
  entry.material.transparent=value<.995||entry.transparent;
 }
}
function prepareAvatar(model){
 const materials=[];
 model.traverse(obj=>{
  if(!obj.isMesh)return;
  obj.frustumCulled=false; // animated skeletal bounds are often inaccurate
  if(obj.material){
   const originals=Array.isArray(obj.material)?obj.material:[obj.material];
   const copies=originals.map(m=>{
    const material=m.clone();materials.push({material,opacity:m.opacity,transparent:m.transparent});
    return material;
   });
   obj.material=Array.isArray(obj.material)?copies:copies[0];
  }
 });
 return materials;
}
// Animation policy: actual travel=walk only; at a destination choose
// dance, drink, sit or idle. No dance/drink fallback for locomotion.
const MOTION_BY_ACTIVITY={dance:'dance',bar:'drink',sofa:'sit',chat:'idle'};
function resetAvatarTransition(p){
 if(!p.fadingItem)return;
 const outgoing=p.fadingItem;
 outgoing.mesh.visible=false;
 setAvatarOpacity(outgoing,1);
 outgoing.action?.stop();
 p.fadingItem=null;
 p.fadeTime=0;
}
// ONE avatar/skeleton per guest. All clips are played through the same
// AnimationMixer, so no 3D model swap, transparent ghosts or rest-pose flashes.
function actorState(p,motion){
 const assets=actorAssets[p.variant]||{};
 const asset=assets[motion];
 if(!asset){
  console.warn('Missing '+motion+' animation for',variants[p.variant]);
  return false;
 }
 if(!p.avatar){
  const base=assets.walk;
  if(!base)return false;
  p.avatar=cloneSkeleton(base.scene);
  fitCharacterHeight(p.avatar,1.65);
  p.avatarMaterials=prepareAvatar(p.avatar);
  p.group.add(p.avatar);
  p.mixer=new THREE.AnimationMixer(p.avatar);
  p.cache={};
 }
 let item=p.cache[motion];
 if(!item){
  const keyword=motion==='sit'?'sit':motion;
  const clip=asset.animations?.find(c=>c.name.toLowerCase().includes(keyword))||asset.animations?.[0];
  if(!clip){console.warn('No animation clip:',variants[p.variant],motion);return false;}
  const action=p.mixer.clipAction(clip);
  item={action,clip};
  p.cache[motion]=item;
 }
 if(p.motion===motion&&p.activeItem===item)return true;
 const prev=p.activeItem?.action;
 const next=item.action;
 // All actions share one mesh and one skeleton. Stop root-motion side
 // effects from overlapping visual clones by blending bone transforms.
 next.enabled=true;
 next.paused=false;
 next.setEffectiveWeight(1);
 next.setEffectiveTimeScale(1);
 next.setLoop(motion==='sit'?THREE.LoopOnce:THREE.LoopRepeat,motion==='sit'?1:Infinity);
 next.clampWhenFinished=motion==='sit';
 next.reset().play();
 if(motion==='dance')next.time=Math.random()*Math.max(item.clip.duration,.1);
 if(prev&&prev!==next){
  const duration=motion==='walk'?.15:motion==='sit'?.20:.24;
  next.crossFadeFrom(prev,duration,false);
  // Start walking shortly before moving coordinates, so the end of the
  // previous activity cannot visually glide along the floor.
  if(motion==='walk')p.walkBlendDelay=duration;
 }else if(motion==='walk')p.walkBlendDelay=0;
 p.motion=motion;p.mesh=p.avatar;p.activeItem=item;p.fadingItem=null;
 p.mixer.update(0);
 return true;
}
function enforceWalkingVisual(p){
 if(p.motion!=='walk')actorState(p,'walk');
}
function updateAvatar(p,dt){
 p.mixer?.update(dt);
}
function routeGuest(p,activity,preferredSpot=null){
 // Optional actions arrive later than core walk/dance. Keep guests safely
 // dancing until their own GLB action finishes loading.
 if(activity==='bar'&&!actorAssets[p.variant]?.drink)activity='dance';
 if(activity==='sofa'&&!actorAssets[p.variant]?.sit)activity='dance';
 if(activity==='chat'&&!actorAssets[p.variant]?.idle)activity='dance';
 releaseSpot(p);
 let destination=reserveDestination(p,activity,preferredSpot);
 // Busy bar/sofas: wait on a free dance tile and try again on the next decision.
 if(!destination&&activity!=='dance'){
  activity='dance';
  destination=reserveDestination(p,'dance');
 }
 if(!destination){
  // All tiles reserved: do not stack another guest onto a taken tile.
  p.wait=1.5;p.state='waiting';
  actorState(p,'walk');return false;
 }
 p.activity=activity;p.wait=0;
 p.x=destination.x;
 p.z=destination.z;
 p.sofaBack=activity==='sofa'&&destination.z>6;
 actorState(p,'walk');
 p.state='walk';
 return true;
}
function createChatPair(){
 const candidates=guests.filter(p=>p.state==='dance'&&!p.chatPartner&&!p.fadingItem&&actorAssets[p.variant]?.idle);
 if(candidates.length<2)return;
 const station=pick(chatStations.filter(pair=>pair.every(spot=>!reservedSpots.has(spotKey('chat',spot)))));
 if(!station)return;
 const a=pick(candidates);
 const b=pick(candidates.filter(p=>p!==a));
 a.chatPartner=b;b.chatPartner=a;
 a.chatStarted=false;b.chatStarted=false;
 a.chatDuration=b.chatDuration=7+Math.random()*6;
 // Both locations are reserved before either guest starts walking.
 routeGuest(a,'chat',station[0]);
 routeGuest(b,'chat',station[1]);
}
function addGuest(){
 if(!running||paused||ending||guests.length>=guestCapacity)return;
 const available=[...readyGuestVariants];
 if(!available.length)return;
 const variant=pick(available);
 // Every guest is created at the two-cell entrance, never at their dance destination.
 const group=new THREE.Group();
 group.position.set((Math.random()-.5)*.7,.05,7.45);
 stage.add(group);
 const p={group,mesh:null,mixer:null,motion:null,state:null,variant,x:0,z:0,speed:1.0+Math.random()*.65,phase:Math.random()*6.28,
 energy:.55+Math.random()*.45,thirst:Math.random()*.3,wait:0,activity:'dance',cache:{},visits:0,
 entryPending:true,entryX:group.position.x,entryZ:5.4};
 routeGuest(p,'dance');
 // Render the model at the doorway in its already-evaluated walking pose.
 p.group.updateMatrixWorld(true);
 guests.push(p);
 $('counter').textContent='GUESTS: '+guests.length+' / '+guestCapacity;
}
function removeGuests(){for(const p of guests)cleanGuest(p);guests.length=0;reservedSpots.clear();$('counter').textContent='GUESTS: 0 / '+guestCapacity;}
$('openClub').onclick=()=>{
 opened=true;$('curtain').style.display='none';
 $('play').disabled=false;
 $('stageStatus').textContent='Клуб открыт. Выбери DJ и начинай вечеринку!';
 startGuestPreload();
};
function updatePauseButton(){
 $('pause').disabled=!running||ending;
 $('pause').textContent=paused?'ПРОДОЛЖИТЬ':'ПАУЗА';
}
function togglePause(){
 if(!running||ending)return;
 paused=!paused;
 if(paused){
  scWidget?.pause();
  for(const p of guests){
   p.pausedAnimation={
    motion:p.motion,
    time:p.activeItem?.action?.time||0,
    speed:p.activeItem?.action?.getEffectiveTimeScale?.()||1,
    wasPaused:!!p.activeItem?.action?.paused
   };
   if(actorAssets[p.variant]?.idle)actorState(p,'idle');
   else if(p.activeItem?.action)p.activeItem.action.paused=true;
  }
  $('stageStatus').textContent='Пауза · свет включён, гости отдыхают. Нажми «Продолжить».';
  musicStatus.textContent='Музыка на паузе.';
 }else{
  // SoundCloud PLAY must be issued synchronously in the Resume button's
  // trusted click handler, before any scene work, for browser media policies.
  scRequested=true;
  scWidget?.play();
  for(const p of guests){
   const snapshot=p.pausedAnimation;
   if(!snapshot)continue;
   actorState(p,snapshot.motion||'walk');
   const action=p.activeItem?.action;
   if(action){
    action.time=snapshot.time;
    action.setEffectiveTimeScale(snapshot.speed);
    action.paused=snapshot.wasPaused;
    if(snapshot.motion==='sit'){action.setLoop(THREE.LoopOnce,1);action.clampWhenFinished=true;}
    p.mixer?.update(0);
   }
   p.pausedAnimation=null;
  }
  musicStatus.textContent='Продолжаю воспроизведение SoundCloud…';
  // If the embedded player refuses automatic resume, report it clearly
  // instead of pretending that the music is playing.
  if(scReady&&scWidget?.getPaused){
   setTimeout(()=>{
    if(running&&!paused&&!ending){
     scWidget.getPaused(isPaused=>{
      if(isPaused&&running&&!paused&&!ending){
       musicStatus.textContent='SoundCloud приостановлен браузером. Нажми Play в плеере.';
      }
     });
    }
   },900);
  }
  $('stageStatus').textContent='Вечеринка продолжается · '+nameToLabel[$('dj').value]+' за пультом.';
 }
 updatePauseButton();
}
function cleanGuest(p){
 releaseSpot(p);p.chatPartner=null;
 if(p.mixer&&p.avatar){
  p.mixer.stopAllAction();
  p.mixer.uncacheRoot(p.avatar);
 }
 p.avatar?.traverse(obj=>{
  if(obj.isSkinnedMesh)obj.skeleton?.dispose();
 });
 p.avatarMaterials?.forEach(entry=>entry.material.dispose());
 stage.remove(p.group);
 p.cache={};p.activeItem=null;p.fadingItem=null;p.mesh=null;p.mixer=null;p.avatar=null;p.avatarMaterials=null;
}
function completeParty(){
 ending=false;running=false;paused=false;guestsReady=false;
 // A progressive load might still be in flight when the last person exits.
 // Do not let a new party reuse assets while the old set is being disposed.
 const finishingLoad=actorPromise;
 $('dj').disabled=true;$('play').disabled=true;$('end').disabled=true;
 updatePauseButton();
 $('counter').textContent='GUESTS: 0 / '+guestCapacity;
 $('stageStatus').textContent=endMessage;
 const finalize=()=>{
  if(running||ending||actorPromise!==finishingLoad)return;
  releaseGuestAssets();
  $('dj').disabled=false;$('play').disabled=false;
 };
 if(finishingLoad)finishingLoad.then(finalize,finalize);
 else{
  releaseGuestAssets();
  $('dj').disabled=false;$('play').disabled=false;
 }
}
let endMessage='Вечеринка закончилась. Все гости вышли.';
function endParty(message='Вечеринка завершена. Все гости вышли.'){
 if(ending||(!running&&!paused))return;
 ending=true;running=false;paused=false;guestsReady=false;scRequested=false;scStarted=false;
 updatePosterScreens(nameToLabel[$('dj').value],false);
 scWidget?.pause();
 endMessage=message;
 $('play').disabled=true;$('pause').disabled=true;$('end').disabled=true;
 $('stageStatus').textContent='Свет включён. Гости направляются к выходу…';
 musicStatus.textContent='Воспроизведение остановлено.';
 guests.forEach((p,i)=>{
  releaseSpot(p);p.chatPartner=null;p.pausedAnimation=null;
  p.entryPending=false;p.state='exit';p.activity='exit';
  p.exitStep=0;p.exitDelay=i*.13;
  p.x=0;p.z=6.7;
  actorState(p,'walk');
 });
 reservedSpots.clear();
 if(!guests.length)completeParty();
}
function animateExits(dt){
 for(let i=guests.length-1;i>=0;i--){
  const p=guests[i];
  if(p.exitDelay>0){p.exitDelay-=dt;updateAvatar(p,dt);continue;}
  const targetX=p.exitStep===0?0:p.exitX;
  const targetZ=p.exitStep===0?6.7:8.7;
  const dx=targetX-p.group.position.x,dz=targetZ-p.group.position.z;
  const dist=Math.hypot(dx,dz);
  if(dist<.17){
   if(p.exitStep===0){p.exitStep=1;p.exitX=(i%3-1)*.22;}
   else{cleanGuest(p);guests.splice(i,1);}
  }else{
   const step=Math.min(p.speed*dt,dist);
   p.group.position.x+=dx/dist*step;p.group.position.z+=dz/dist*step;
   p.group.rotation.y=Math.atan2(dx,dz);
   updateGuestElevation(p,dt);
   updateAvatar(p,dt);
  }
 }
 $('counter').textContent='GUESTS: '+guests.length+' / '+guestCapacity;
 if(!guests.length)completeParty();
}
$('play').onclick=async()=>{
 if(!opened||running||ending)return;
 running=true;paused=false;guestsReady=false;partyTime=0;guestClock=0;chatClock=0;
 updatePosterScreens(nameToLabel[$('dj').value],true);
 guestCapacity=getGuestCapacity();
 removeGuests();
 $('dj').disabled=true;$('play').disabled=true;$('end').disabled=false;
 updatePauseButton();
 $('stageStatus').textContent='Загружаю анимации гостей… После загрузки они начнут входить через дверь.';
 scRequested=true;
 musicStatus.textContent='Запускаю музыку… Если браузер запретил автозапуск, нажми Play в плеере.';
 if(scWidget)scWidget.play();
 else musicStatus.textContent='Плеер SoundCloud недоступен. Воспроизведи трек вручную.';
 // Download may already be underway while the player selects the DJ.
 // The first ready walk+dance rig starts walking from the entrance immediately.
 startGuestPreload();
 if(readyGuestVariants.size){
  guestsReady=true;guestClock=0;
  $('stageStatus').textContent='Вечеринка идёт · '+nameToLabel[$('dj').value]+' за пультом. Ожидается до '+guestCapacity+' гостей.';
  addGuest();
 }
};
$('pause').onclick=togglePause;
$('end').onclick=()=>endParty();
let djNextAction=8,djPose='idle';
function animateDJ(){
 if(!djActors.idle)return;
 if(partyTime>=djNextAction){
  const r=Math.random();
  djPose=!running?'idle':r<.70?'idle':r<.90?'standing':'party';
  djNextAction=partyTime+(djPose==='idle'?7+Math.random()*11:2+Math.random()*4);
 }
 for(const [state,actor] of Object.entries(djActors))actor.visible=state===djPose;
}
function sitAction(p,reverse=false){
 const action=p.cache?.sit?.action;
 if(!action)return 0;
 const duration=Math.max(.25,action.getClip().duration);
 action.enabled=true;
 action.setLoop(THREE.LoopOnce,1);
 action.clampWhenFinished=true;
 if(reverse){
  // Keep the last seated pose, then play the clip in reverse on the SAME rig.
  action.stop();
  action.reset();
  action.setEffectiveTimeScale(-1);
  action.time=Math.max(0,duration-.001);
  action.play();
 }else{
  action.setEffectiveTimeScale(1);
  action.paused=false;
  // The transition to sit has already started this clip with a crossfade.
 }
 action.paused=false;
 p.mixer?.update(0);
 return duration;
}
function updateGuest(p,dt){
 updateGuestElevation(p,dt);
 if(p.state==='waiting'){
  p.wait-=dt;
  if(p.wait<=0)routeGuest(p,'dance');
  return;
 }
 p.thirst=Math.min(1,p.thirst+dt*(p.state==='dance'?.008:.003));
 p.energy=Math.max(0,p.energy-dt*(p.state==='dance'?.004:.001));
 if(p.state==='walk'){
  // Hard invariant: locomotion never renders a dance, drink or sit pose.
  enforceWalkingVisual(p);
  // Walk inside from the door before taking the path to the reserved tile.
  const targetX=p.entryPending?p.entryX:p.x;
  const targetZ=p.entryPending?p.entryZ:p.z;
  const dx=targetX-p.group.position.x,dz=targetZ-p.group.position.z,dist=Math.hypot(dx,dz);
  if(p.entryPending&&dist<.13){
   p.entryPending=false;
   return;
  }
  if(dist<.13){
   if(p.activity==='dance'){actorState(p,'dance');p.state='dance';p.wait=7+Math.random()*12;}
   else if(p.activity==='bar'){actorState(p,'drink');p.state='drink';p.wait=3+Math.random()*4;}
   else if(p.activity==='chat'){
    actorState(p,'idle');p.state='chat_wait';p.wait=0;
    const other=p.chatPartner;
    if(other){p.group.rotation.y=Math.atan2(other.group.position.x-p.group.position.x,other.group.position.z-p.group.position.z);
     if(other.state==='chat_wait'){
      p.state='chat';other.state='chat';p.wait=other.wait=p.chatDuration;
      other.group.rotation.y=Math.atan2(p.group.position.x-other.group.position.x,p.group.position.z-other.group.position.z);
     }
    }
   }
   else{
    // Sofa model faces the room; rear-wall sofas need the opposite orientation.
    p.group.rotation.y=p.sofaBack?Math.PI:(p.group.position.x<0?Math.PI/2:-Math.PI/2);
    actorState(p,'sit');
    p.wait=sitAction(p);
    p.state='sit_down';
   }
   if(p.activity==='bar')p.group.rotation.y=p.group.position.x<0?-Math.PI/2:Math.PI/2;
  }else{
   if(p.walkBlendDelay>0){p.walkBlendDelay=Math.max(0,p.walkBlendDelay-dt);return;}
   const step=Math.min(p.speed*dt,dist);
   p.group.position.x+=dx/dist*step;p.group.position.z+=dz/dist*step;p.group.rotation.y=Math.atan2(dx,dz);
  }
  return;
 }
 if(p.state==='chat_wait')return;
 p.wait-=dt;
 if(p.wait>0)return;
 if(p.state==='chat'){
  const other=p.chatPartner;
  p.chatPartner=null;
  if(other?.chatPartner===p)other.chatPartner=null;
  routeGuest(p,'dance');return;
 }
 if(p.state==='sit_down'){
  p.state='resting';p.wait=3+Math.random()*2;
  if(p.activeItem?.action)p.activeItem.action.paused=true;
  return;
 }
 if(p.state==='resting'){
  p.state='sit_up';p.wait=sitAction(p,true);
  return;
 }
 if(p.state==='sit_up'){
  p.energy=Math.min(1,p.energy+.55);p.visits++;routeGuest(p,'dance');return;
 }
 if(p.state==='drink'){
  p.thirst=Math.max(0,p.thirst-.75);p.energy=Math.min(1,p.energy+.04);
  p.visits++;routeGuest(p,'dance');return;
 }
 if(p.thirst>.48)routeGuest(p,'bar');
 else if(p.energy<.38)routeGuest(p,'sofa');
 else if(Math.random()<.18)routeGuest(p,Math.random()<.5?'bar':'sofa');
 else routeGuest(p,'dance');
}

// Begin core preload once the venue models have finished loading, even
// before opening the club. It overlaps selection time rather than party time.
Promise.all([wallLoad,peopleExtras]).then(()=>{
 if(!actorPromise)startGuestPreload();
}).catch(error=>console.warn('Guest preload postponed:',error));
const resize=new ResizeObserver(()=>{const w=mount.clientWidth,h=mount.clientHeight;if(w&&h){camera.aspect=w/h;camera.updateProjectionMatrix();renderer.setSize(w,h);}});resize.observe(mount);
let t=0;function frame(){requestAnimationFrame(frame);let dt=Math.min(clock.getDelta(),.05);t+=dt;controls.update();const partyActive=running&&!paused&&!ending;const target=partyActive?1:0;const quality=fxSettings[fxQuality];
if(!partyActive){djPose='idle';djNextAction=8;
 for(const [state,actor] of Object.entries(djActors))actor.visible=state==='idle';
}else animateDJ();
for(const mixer of extraMixers)mixer.update(dt);
hemi.intensity+=((partyActive?1.65:2.3)-hemi.intensity)*.025;sun.intensity+=((partyActive?.92:2)-sun.intensity)*.025;
scene.background.lerp(new THREE.Color(partyActive?0x050410:0x090b16),.02);
scene.fog.color.copy(scene.background);
scene.fog.density+=((partyActive?.014:.018)-scene.fog.density)*.016;
hazeLayers.forEach((layer,i)=>{
 const m=layer.mesh;
 m.visible=i<quality.smoke;
 // Slowly billowing haze, strongest at the dancefloor but transparent enough
 // to see dancers and the club furniture from an elevated camera.
 const density=partyActive?(.23+.09*Math.sin(t*.21+layer.offset))*(i%3===0?1.25:1):0;
 m.material.opacity+=(density-m.material.opacity)*.018;
 m.position.x=layer.baseX+Math.sin(t*.11+layer.offset)*.56;
 m.position.z=layer.baseZ+Math.cos(t*.08+layer.offset)*.43;
 m.position.y=.7+(.5+.5*Math.sin(t*.10+layer.offset))*.95;
});
venueFills.forEach((l,i)=>{l.intensity+=((partyActive?2.75*quality.brightness:0)-l.intensity)*.025;});
wallWashes.forEach((l,i)=>{l.intensity+=((partyActive&&fxQuality!=='low'?1.3*quality.brightness:0)-l.intensity)*.025;});
beams.forEach((l,i)=>{l.intensity=target*(3+2*Math.sin(t*(i+3)));l.position.x=(i?4:-4)+Math.sin(t*.8+i)*2;});
animateFixtures(t,dt,partyActive);
animateDanceFloor(dt,partyActive,t);
if(partyActive){
 partyTime+=dt;guestClock+=dt;chatClock+=dt;
 if(chatClock>16){chatClock=0;createChatPair();}
 if(guestsReady&&guestClock>1.25&&guests.length<guestCapacity){guestClock=0;addGuest();}
 for(const p of guests)updateGuest(p,dt);
 // Advance animated poses every rendered frame. A 30fps mixer with 120fps
 // locomotion previously created visible stepping/jitter in all variants.
 for(const p of guests){
  if(p.state==='walk'||p.state==='exit')enforceWalkingVisual(p);
  updateAvatar(p,dt);
 }
}else if(ending){
 animateExits(dt);
}else if(paused){
 // Advance only the idle animation: routes, thirst, energy and party time stay frozen.
 for(const p of guests)updateAvatar(p,dt);
}

renderer.render(scene,camera)}
frame();
