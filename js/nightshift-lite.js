import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {clone as cloneSkeleton} from 'three/addons/utils/SkeletonUtils.js';

const $=id=>document.getElementById(id);
const mount=$('scene'), scene=new THREE.Scene();
scene.background=new THREE.Color('#090b16'); scene.fog=new THREE.FogExp2('#0c0b17',.024);
const renderer=new THREE.WebGLRenderer({antialias:true,powerPreference:'high-performance'});
renderer.setPixelRatio(Math.min(devicePixelRatio,1.4));
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
const loadGLB=path=>new Promise(resolve=>loader.load(path,resolve,undefined,err=>{console.warn('Optional GLB not loaded',path,err);resolve(null)}));
const mat=(color,roughness=.85)=>new THREE.MeshStandardMaterial({color,roughness});
const concrete=mat(0x252330),dark=mat(0x302c3c),danceMat=mat(0x503463),edgeMat=mat(0x50455a);
function block(w,h,d,x,y,z,material,parent=stage){const o=new THREE.Mesh(new THREE.BoxGeometry(w,h,d),material);o.position.set(x,y,z);parent.add(o);return o;}
block(16,.2,16,0,-.15,0,concrete);
for(let i=-7.5;i<=7.5;i+=1){block(1,1.55,.26,i,.68,-7.9,dark);block(.26,1.55,1,-7.9,.68,i,dark);}
for(let i=-7.5;i<=7.5;i+=1)if(Math.abs(i)>1)block(1,1.55,.26,i,.68,7.9,dark);
for(let i=-7.5;i<=7.5;i+=1)block(.26,1.55,1,7.9,.68,i,dark);
block(3,.035,3,0,.02,-3.8,danceMat);
for(let x=-3.5;x<=3.5;x++)for(let z=-2.5;z<=3.5;z++)block(.95,.025,.95,x,.02,z,danceMat);
const decor=[
['dj_stand_upgraded',0,-5.1,2.6],['speaker_updated',-2.9,-5.4,1.6],['speaker_updated',2.9,-5.4,1.6],
['bar_new',5.9,2.4,2.4],['sofa_upgraded',-5.4,3.1,2.4],
['plant_big',-6,-5.6,1.6],['plant2',6,-5.2,1.25],
['laser_new',-4.8,-3.7,1.2],['light',4.8,-3.7,1.2],
['discoball',0,4.5,2.0],['poster',-6.9,-2,1.7],
['table',-5,1.1,1.1],['stool',4.6,3.2,.8]
];
function fitModel(root,size){root.updateMatrixWorld(true);let box=new THREE.Box3().setFromObject(root);
if(box.isEmpty())return;const ext=new THREE.Vector3();box.getSize(ext);
root.scale.multiplyScalar(size/Math.max(ext.x,ext.z,.001));
root.updateMatrixWorld(true);box=new THREE.Box3().setFromObject(root);
const mid=new THREE.Vector3();box.getCenter(mid);
root.position.x-=mid.x;root.position.z-=mid.z;root.position.y-=box.min.y;
}
let ready3d=false;
Promise.all(decor.map(async([name,x,z,size])=>{
 const gltf=await loadGLB('godot/assets/models/'+name+'.glb');
 if(!gltf)return;
 const holder=new THREE.Group(),obj=gltf.scene;
 fitModel(obj,size);holder.position.set(x,.04,z);holder.add(obj);stage.add(holder);
 if(name==='discoball')window.discoball=holder;
})).then(()=>{ready3d=true;$('loading').textContent='Клуб готов.'});
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
$('loadSheet').onclick=loadSheet;const stored=localStorage.getItem('nightshift-lite-sheet');if(stored){$('sheet').value=stored;loadSheet();}
const variants=['baggy_m','fashion_f','jungle_f','raver_f','raver_m'];
const actorAssets={};
let loaded=0;
const actorPromise=Promise.all(variants.flatMap((name,i)=>['idle','walk','dance'].map(async state=>{
 const g=await loadGLB('assets/characters/'+name+'_'+state+'.glb');
 if(!actorAssets[i])actorAssets[i]={};
 if(g)actorAssets[i][state]=g; loaded++;
}))).then(()=>{$('loading').textContent='Гости и анимации загружены.';return true});
let opened=false,running=false,guestClock=0,partyTime=0;const guests=[];const clock=new THREE.Clock();
function actorState(p,state){if(p.state===state)return;
if(p.mesh){p.group.remove(p.mesh);if(p.mixer)p.mixer.stopAllAction();}
const asset=actorAssets[p.variant]?.[state]||actorAssets[p.variant]?.dance||actorAssets[p.variant]?.idle;
p.state=state;p.mixer=null;
if(!asset){p.mesh=new THREE.Mesh(new THREE.CapsuleGeometry(.22,.72,3,5),mat(0x965bd1));p.mesh.position.y=.55;p.group.add(p.mesh);return}
const model=cloneSkeleton(asset.scene);fitModel(model,.65);
model.scale.multiplyScalar(1.45);p.group.add(model);p.mesh=model;
if(asset.animations.length){p.mixer=new THREE.AnimationMixer(model);const a=p.mixer.clipAction(asset.animations[0]);a.play();a.time=Math.random()*Math.max(a.getClip().duration,.1);}
}
function addGuest(){if(!running||guests.length>=20)return;
const variant=Math.floor(Math.random()*variants.length);
const x=-3.35+Math.random()*6.7,z=-2.25+Math.random()*5.7;
const group=new THREE.Group();group.position.set(0,.05,7);stage.add(group);
const p={group,mesh:null,mixer:null,state:null,variant,x,z,speed:1.1+Math.random()*.5,phase:Math.random()*6.28};actorState(p,'walk');guests.push(p);$('counter').textContent='GUESTS: '+guests.length+' / 20';
}
function removeGuests(){for(const p of guests){p.mixer?.stopAllAction();stage.remove(p.group)}guests.length=0;$('counter').textContent='GUESTS: 0 / 20';}
$('openClub').onclick=()=>{opened=true;$('curtain').style.display='none';$('play').disabled=false;$('stageStatus').textContent='Клуб открыт. Выбери DJ и начинай вечеринку!';};
$('play').onclick=async()=>{if(!opened||running)return;running=true;partyTime=0;guestClock=0;removeGuests();$('dj').disabled=true;$('play').disabled=true;$('end').disabled=false;$('stageStatus').textContent='Вечеринка идёт · '+nameToLabel[$('dj').value]+' за пультом. До 20 гостей на танцполе.';await actorPromise;if(running)addGuest();};
$('end').onclick=()=>{running=false;removeGuests();$('dj').disabled=false;$('play').disabled=false;$('end').disabled=true;$('stageStatus').textContent='Вечеринка закончилась. Выбери следующего DJ.';};
const resize=new ResizeObserver(()=>{const w=mount.clientWidth,h=mount.clientHeight;if(w&&h){camera.aspect=w/h;camera.updateProjectionMatrix();renderer.setSize(w,h);}});resize.observe(mount);
let t=0,animAccum=0;function frame(){requestAnimationFrame(frame);let dt=Math.min(clock.getDelta(),.05);t+=dt;controls.update();const target=running?1:0;
hemi.intensity+=((running?.4:2.3)-hemi.intensity)*.025;sun.intensity+=((running?.15:2)-sun.intensity)*.025;
scene.background.lerp(new THREE.Color(running?0x050410:0x090b16),.02);
beams.forEach((l,i)=>{l.intensity=target*(3+2*Math.sin(t*(i+3)));l.position.x=(i?4:-4)+Math.sin(t*.8+i)*2;});
if(window.discoball)window.discoball.rotation.y+=dt*.4;
if(running){partyTime+=dt;guestClock+=dt;if(guestClock>1.65&&guests.length<20){guestClock=0;addGuest();}
animAccum+=dt;
for(const p of guests){if(p.state==='walk'){const dx=p.x-p.group.position.x,dz=p.z-p.group.position.z,dist=Math.hypot(dx,dz);if(dist<.16){actorState(p,'dance');p.group.rotation.y=Math.random()*Math.PI*2;}else{const step=Math.min(p.speed*dt,dist);p.group.position.x+=dx/dist*step;p.group.position.z+=dz/dist*step;p.group.rotation.y=Math.atan2(dx,dz);}}}
if(animAccum>=1/30){for(const p of guests)p.mixer?.update(animAccum);animAccum=0;}
}
renderer.render(scene,camera)}
frame();
