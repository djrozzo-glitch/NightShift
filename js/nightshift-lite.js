import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {MeshoptDecoder} from 'three/addons/libs/meshopt_decoder.module.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {clone as cloneSkeleton} from 'three/addons/utils/SkeletonUtils.js';

const $=id=>document.getElementById(id);
console.info('NIGHTSHIFT LITE BUILD 04: fixed venue assets');
const mount=$('scene'), scene=new THREE.Scene();
scene.background=new THREE.Color('#090b16'); scene.fog=new THREE.FogExp2('#0c0b17',.024);
const renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance'});
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
const dancePlaceholders=danceTilePositions.map(([x,z])=>block(.98,.05,.98,x,.035,z,danceMat));
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
 for(const [x,z] of danceTilePositions){
  const tile=source.clone(true);
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
function addFixture(holder,obj,name){
 obj.updateMatrixWorld(true);
 const bounds=new THREE.Box3().setFromObject(obj);
 const top=Math.max(.4,bounds.max.y-holder.position.y);
 if(name==='discoball'){
  const points=[];
  const circle=new THREE.CircleGeometry(.105,8);
  for(let i=0;i<40;i++){
   const material=new THREE.MeshBasicMaterial({color:[0xbdb3ff,0xffbddf,0xbceeff,0xffffff][i%4],transparent:true,opacity:0,depthWrite:false,side:THREE.DoubleSide});
   const dot=new THREE.Mesh(circle,material);dot.rotation.x=-Math.PI/2;dot.position.y=.05;stage.add(dot);points.push(dot);
  }
  const glow=new THREE.PointLight(0xcbb9ff,0,8,2);glow.position.y=top-.06;holder.add(glow);
  fixtures.push({name,holder,obj,points,glow,top});
 }else if(name==='laser_new'||name==='light'){
  const colors=name==='laser_new'?[0x31ff64,0x287cff,0xff334d]:[0xc15dff,0x87abff];
  const beams=colors.map(color=>{
   const mesh=new THREE.Mesh(new THREE.CylinderGeometry(.015,.055,1,6,1,true),new THREE.MeshBasicMaterial({color,transparent:true,opacity:0,depthWrite:false,blending:THREE.AdditiveBlending,side:THREE.DoubleSide}));
   stage.add(mesh);return mesh;
  });
  const lamp=new THREE.PointLight(colors[0],0,4,2);lamp.position.y=top-.1;holder.add(lamp);
  fixtures.push({name,holder,top,beams,lamp});
 }
}
const beamStart=new THREE.Vector3(),beamEnd=new THREE.Vector3(),upVector=new THREE.Vector3(0,1,0);
function animateFixtures(t,dt,active){
 for(const fx of fixtures){
  if(fx.name==='discoball'){
   if(active)fx.obj.rotation.y+=dt*.55;
   fx.glow.intensity=active?1.5+Math.sin(t*6)*.4:0;
   fx.points.forEach((p,i)=>{
    const angle=t*.42+i*Math.PI*2/40,radius=2.4+i%5*.59;
    p.position.set(fx.holder.position.x+Math.cos(angle)*radius,.055,fx.holder.position.z+Math.sin(angle)*radius);
    p.material.opacity=active?.25+.35*(.5+.5*Math.sin(t*2+i)):0;
   });
  }else{
   fx.lamp.intensity=active?1.7:0;
   fx.lamp.getWorldPosition(beamStart);
   fx.beams.forEach((beam,i)=>{
    const a=t*(.8+i*.17)+i*1.7;
    beamEnd.set(Math.sin(a)*2.8,.08,-2.5+Math.cos(a*.86)*2.0);
    const dir=beamEnd.clone().sub(beamStart),len=dir.length();
    beam.position.copy(beamStart).addScaledVector(dir,.5);
    beam.quaternion.setFromUnitVectors(upVector,dir.normalize());
    beam.scale.set(1,len,1);
    beam.material.opacity=active?(fx.name==='laser_new'?.35:.10):0;
   });
  }
 }
}
Promise.all(decor.map(async([name,x,z,size,rotation])=>{
 const gltf=await loadVenueModel(name);
 if(!gltf)return;
 const holder=new THREE.Group(),obj=gltf.scene;
 fitModel(obj,size);holder.position.set(x,.04,z);holder.rotation.y=rotation||0;holder.add(obj);stage.add(holder);loadedModels.set(name,holder);
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
let clubName=localStorage.getItem('nightshift-lite-club')||'ABLETON GYM';
function updateClubName(){
 sign.ctx.fillStyle='#130c22';sign.ctx.fillRect(0,0,1024,256);
 sign.ctx.strokeStyle='#a657dd';sign.ctx.lineWidth=18;sign.ctx.strokeRect(9,9,1006,238);
 sign.ctx.fillStyle='#8bffc9';sign.ctx.font='800 84px sans-serif';sign.ctx.textAlign='center';sign.ctx.textBaseline='middle';sign.ctx.fillText(clubName.toUpperCase(),512,128,950);
 sign.texture.needsUpdate=true;
 $('clubName').value=clubName;
}
$('saveClubName').onclick=()=>{const next=$('clubName').value.trim().slice(0,32);if(!next)return;clubName=next;localStorage.setItem('nightshift-lite-club',clubName);updateClubName();};
updateClubName();

const beams=[new THREE.PointLight(0xdd39ff,0,13,2),new THREE.PointLight(0x377dff,0,12,2)];
beams[0].position.set(-4,3,-3);beams[1].position.set(4,3,-4);beams.forEach(l=>scene.add(l));
const nameToLabel={rozzo:'rozzo',neonexus:'Neonexus',vanya:'Vanya Velin',lutanina:'Lutanina',zlostniy:'zlostniy',lowq:'lowQ',velvet37:'Velvet 37',raison:'Raison',boriskhodok:'DJ Boris Khodok'};
const tracks={rozzo:'https://soundcloud.com/irozov/rozzo-waste-my-time-i-dont-1',neonexus:'https://soundcloud.com/amn303/backdoor-radio-mix-neonexus',vanya:'https://soundcloud.com/bcco/bcco-premiere-vanya-velin',lutanina:'https://soundcloud.com/user-880945103/two-rndm-06-02',zlostniy:'https://soundcloud.com/velvet-37/shine-ft-zlostniy',lowq:'https://soundcloud.com/shiftedrecordings/waves-of-light-1',velvet37:'https://soundcloud.com/velvet-37/my-angel-1',raison:'https://soundcloud.com/raison_d_etre/even-sexier-groove',boriskhodok:'https://soundcloud.com/dj-boris-khodok/8-march-mix'};
function syncTrack(){const url=tracks[$('dj').value];$('trackLink').href=url;$('trackLink').textContent='♫ '+nameToLabel[$('dj').value]+' — открыть SoundCloud';$('scFrame').src='https://w.soundcloud.com/player/?url='+encodeURIComponent(url)+'&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&visual=false';}
$('dj').addEventListener('change',()=>{updateFee();syncTrack()});syncTrack();
let fees={};
function csvRows(s){const rows=[];let row=[],field='',quote=false;for(let i=0;i<s.length;i++){const c=s[i];if(c==='"'){if(quote&&s[i+1]==='"'){field+='"';i++}else quote=!quote}else if(c===','&&!quote){row.push(field);field=''}else if((c==='\n'||c==='\r')&&!quote){if(c==='\r'&&s[i+1]==='\n')i++;row.push(field);if(row.some(v=>v.trim()))rows.push(row);row=[];field=''}else field+=c}row.push(field);if(row.some(v=>v.trim()))rows.push(row);return rows}
function updateFee(){const fee=fees[$('dj').value];$('fee').textContent=Number.isFinite(fee)?'€'+new Intl.NumberFormat('nl-NL',{maximumFractionDigits:2}).format(fee):'—';}
async function loadSheet(){const url=$('sheet').value.trim();if(!url){$('sheetStatus').textContent='Вставь CSV-ссылку.';return}if(!/^https:\/\/(docs\.google\.com|drive\.google\.com)\//.test(url)){$('sheetStatus').textContent='Используй опубликованную HTTPS-ссылку Google Sheets.';return}
$('sheetStatus').textContent='Загружаю…';try{const r=await fetch(url,{cache:'no-store'});if(!r.ok)throw Error('HTTP '+r.status);const rows=csvRows((await r.text()).replace(/^\uFEFF/,''));const header=rows.shift().map(x=>x.trim().toLowerCase());const idCol=header.indexOf('id'),feeCol=header.indexOf('fee');if(idCol<0||feeCol<0)throw Error('Нужны колонки id и fee');const next={};for(const row of rows){const id=(row[idCol]||'').trim().toLowerCase(),raw=(row[feeCol]||'').trim().replace(/[€\s]/g,'').replace(',','.');const value=Number(raw);if(Object.hasOwn(nameToLabel,id)&&raw&&Number.isFinite(value)&&value>=0)next[id]=value}if(!Object.keys(next).length)throw Error('Нет распознанных DJ/цен');fees=next;localStorage.setItem('nightshift-lite-sheet',url);$('sheetStatus').textContent='Загружено гонораров: '+Object.keys(fees).length;updateFee()}catch(e){$('sheetStatus').textContent='Ошибка загрузки: '+e.message+'. Проверь публикацию CSV и доступ CORS.'}}
$('loadSheet').onclick=loadSheet;const defaultSheet='https://docs.google.com/spreadsheets/d/1vfeH9qxnX1HcEv_BhwrJGI2qjWHQyDVENAFAzgDaqQ8/gviz/tq?tqx=out:csv';const stored=localStorage.getItem('nightshift-lite-sheet');$('sheet').value=stored||defaultSheet;loadSheet();
const variants=['baggy_m','fashion_f','jungle_f','raver_f','raver_m'];
const actorAssets={};
let loaded=0;
let actorPromise=null;
// Service animations are loaded only when the first party begins, keeping startup light.
const guestAnimationFiles={
 baggy_m:{walk:'baggy_m_walk.glb',dance:'baggy_m_dance.glb',drink:'baggy_m_drink.glb',sit:'baggy_m_sit.glb'},
 fashion_f:{walk:'fashion_f_walk.glb',dance:'fashion_f_dance.glb',drink:'fashion_f_drink.glb',sit:'fashion_f_sit.glb'},
 jungle_f:{walk:'jungle_f_walk.glb',dance:'jungle_f_dance.glb',drink:'jungle_f_drink.glb',sit:'jungle_f_sit.glb'},
 raver_f:{walk:'raver_f_walk.glb',dance:'raver_f_dance.glb',drink:'raver_f_chat.glb',sit:'raver_f_sit.glb'},
 raver_m:{walk:'raver_m_walk.glb',dance:'raver_m_dance.glb',drink:'raver_m_idle.glb',sit:'raver_m_sit 2.glb'}
};
function loadGuestsOnDemand(){return actorPromise ||= Promise.all(variants.flatMap((name,i)=>
 Object.entries(guestAnimationFiles[name]).map(async([state,file])=>{
  const g=await loadGLB('assets/characters/'+encodeURIComponent(file));
  if(!actorAssets[i])actorAssets[i]={};
  if(g)actorAssets[i][state]=g;loaded++;
 })
)).then(()=>true);}
const MAX_GUESTS=40;
let opened=false,running=false,guestClock=0,partyTime=0;
const guests=[];const clock=new THREE.Clock();
const pick=arr=>arr[Math.floor(Math.random()*arr.length)];
const danceSpot=()=>({x:-3.5+Math.floor(Math.random()*8),z:-5.5+Math.floor(Math.random()*7)});
const barSpots=[{x:-6.4,z:-4},{x:6.4,z:-4}];
const sofaSpots=[{x:-6.4,z:5},{x:6.4,z:5},{x:-3,z:6.65-1/3},{x:3,z:6.65-1/3}];
function actorState(p,state){
 if(p.state===state)return;
 if(p.mesh)p.mesh.visible=false;
 if(p.mixer)p.mixer.stopAllAction();
 p.cache ||= {};
 let item=p.cache[state];
 if(!item){
  const asset=actorAssets[p.variant]?.[state]||actorAssets[p.variant]?.dance||actorAssets[p.variant]?.walk;
  if(!asset){const mesh=new THREE.Mesh(guestFallbackGeometry,guestFallbackMaterial);mesh.position.y=.55;p.group.add(mesh);item={mesh,mixer:null};}
  else{
   const mesh=cloneSkeleton(asset.scene);fitCharacterHeight(mesh,1.65);p.group.add(mesh);
   const mixer=asset.animations.length?new THREE.AnimationMixer(mesh):null;
   if(mixer)mixer.clipAction(asset.animations[0]).play();
   item={mesh,mixer};
  }
  p.cache[state]=item;
 }
 p.mesh=item.mesh;p.mesh.visible=true;p.mixer=item.mixer;p.state=state;
 if(p.mixer){const action=p.mixer._actions?.[0];if(action){action.reset().play();action.time=Math.random()*Math.max(action.getClip().duration,.1);}}
}
const guestFallbackGeometry=new THREE.CapsuleGeometry(.22,.72,3,5);
const guestFallbackMaterial=mat(0x965bd1);
function routeGuest(p,activity){
 p.activity=activity;p.wait=0;
 const destination=activity==='bar'?pick(barSpots):activity==='sofa'?pick(sofaSpots):danceSpot();
 p.x=destination.x+(activity==='dance'?(Math.random()-.5)*.38:0);
 p.z=destination.z+(activity==='dance'?(Math.random()-.5)*.38:0);
 p.sofaBack=activity==='sofa'&&destination.z>6;
 actorState(p,'walk');
}
function addGuest(){
 if(!running||guests.length>=MAX_GUESTS)return;
 const variant=Math.floor(Math.random()*variants.length);
 const group=new THREE.Group();group.position.set((Math.random()-.5)*1.1,.05,7.2);stage.add(group);
 const p={group,mesh:null,mixer:null,state:null,variant,x:0,z:0,speed:1.0+Math.random()*.65,phase:Math.random()*6.28,
 energy:.55+Math.random()*.45,thirst:Math.random()*.3,wait:0,activity:'dance',cache:{},visits:0};
 routeGuest(p,'dance');guests.push(p);$('counter').textContent='GUESTS: '+guests.length+' / '+MAX_GUESTS;
}
function removeGuests(){for(const p of guests){for(const state of Object.values(p.cache||{}))state.mixer?.stopAllAction();stage.remove(p.group)}guests.length=0;$('counter').textContent='GUESTS: 0 / '+MAX_GUESTS;}
$('openClub').onclick=()=>{opened=true;$('curtain').style.display='none';$('play').disabled=false;$('stageStatus').textContent='Клуб открыт. Выбери DJ и начинай вечеринку!';};
$('play').onclick=async()=>{if(!opened||running)return;running=true;partyTime=0;guestClock=0;removeGuests();$('dj').disabled=true;$('play').disabled=true;$('end').disabled=false;$('stageStatus').textContent='Вечеринка идёт · '+nameToLabel[$('dj').value]+' за пультом. До '+MAX_GUESTS+' гостей, танцы, бары и диваны.';await loadGuestsOnDemand();if(running)addGuest();};
$('end').onclick=()=>{running=false;removeGuests();$('dj').disabled=false;$('play').disabled=false;$('end').disabled=true;$('stageStatus').textContent='Вечеринка закончилась. Выбери следующего DJ.';};
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
 const item=p.cache?.sit,action=item?.mixer?._actions?.[0];
 if(!action)return 0;
 const duration=Math.max(.25,action.getClip().duration);
 action.enabled=true;action.paused=false;action.setLoop(THREE.LoopOnce,1);action.clampWhenFinished=true;
 action.reset();action.time=reverse?duration:0;
 action.timeScale=reverse?-1:1;
 action.play();
 return duration;
}
function updateGuest(p,dt){
 p.thirst=Math.min(1,p.thirst+dt*(p.state==='dance'?.008:.003));
 p.energy=Math.max(0,p.energy-dt*(p.state==='dance'?.004:.001));
 if(p.state==='walk'){
  const dx=p.x-p.group.position.x,dz=p.z-p.group.position.z,dist=Math.hypot(dx,dz);
  if(dist<.13){
   if(p.activity==='dance'){actorState(p,'dance');p.wait=7+Math.random()*12;}
   else if(p.activity==='bar'){actorState(p,'drink');p.wait=3+Math.random()*4;}
   else{
    // Sofa model faces the room; rear-wall sofas need the opposite orientation.
    p.group.rotation.y=p.sofaBack?Math.PI:(p.group.position.x<0?Math.PI/2:-Math.PI/2);
    actorState(p,'sit');
    p.wait=sitAction(p);
    p.state='sit_down';
   }
   if(p.activity==='bar')p.group.rotation.y=p.group.position.x<0?-Math.PI/2:Math.PI/2;
  }else{
   const step=Math.min(p.speed*dt,dist);
   p.group.position.x+=dx/dist*step;p.group.position.z+=dz/dist*step;p.group.rotation.y=Math.atan2(dx,dz);
  }
  return;
 }
 p.wait-=dt;
 if(p.wait>0)return;
 if(p.state==='sit_down'){
  p.state='resting';p.wait=3+Math.random()*2;
  if(p.mixer?._actions?.[0])p.mixer._actions[0].paused=true;
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

const monitor=document.createElement('div');
monitor.style.cssText='position:absolute;right:14px;top:60px;z-index:3;color:#baffd8;background:#080916bd;border:1px solid #365b56;border-radius:6px;padding:6px 9px;font:11px monospace;pointer-events:none';
mount.appendChild(monitor);
let fpsCount=0,fpsClock=0;
function monitorFrame(dt){fpsCount++;fpsClock+=dt;if(fpsClock>=1.5){const fps=Math.round(fpsCount/fpsClock),info=renderer.info;
 const memory=performance.memory?Math.round(performance.memory.usedJSHeapSize/1048576)+'MB JS':'JS heap n/a';
 monitor.textContent='FPS '+fps+' | '+memory+' | GEO '+info.memory.geometries+' | TEX '+info.memory.textures+' | GUESTS '+guests.length;
 fpsClock=0;fpsCount=0;}}
const resize=new ResizeObserver(()=>{const w=mount.clientWidth,h=mount.clientHeight;if(w&&h){camera.aspect=w/h;camera.updateProjectionMatrix();renderer.setSize(w,h);}});resize.observe(mount);
let t=0,animAccum=0;function frame(){requestAnimationFrame(frame);let dt=Math.min(clock.getDelta(),.05);t+=dt;monitorFrame(dt);controls.update();const target=running?1:0;
if(!running){djPose='idle';djNextAction=8;}
else animateDJ();
for(const mixer of extraMixers)mixer.update(dt);
hemi.intensity+=((running?.4:2.3)-hemi.intensity)*.025;sun.intensity+=((running?.15:2)-sun.intensity)*.025;
scene.background.lerp(new THREE.Color(running?0x050410:0x090b16),.02);
beams.forEach((l,i)=>{l.intensity=target*(3+2*Math.sin(t*(i+3)));l.position.x=(i?4:-4)+Math.sin(t*.8+i)*2;});
animateFixtures(t,dt,running);
if(running){
 partyTime+=dt;guestClock+=dt;
 if(guestClock>1.25&&guests.length<MAX_GUESTS){guestClock=0;addGuest();}
 animAccum+=dt;
 for(const p of guests)updateGuest(p,dt);
 if(animAccum>=1/30){for(const p of guests)p.mixer?.update(animAccum);animAccum=0;}
}

renderer.render(scene,camera)}
frame();
