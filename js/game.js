
(()=>{'use strict';const canvas=document.getElementById('game'),ctx=canvas.getContext('2d');const $=id=>document.getElementById(id);let N=16;const TILE_W=54,TILE_H=27;const DJS={
 rozzo:{fee:500,genre:'Deep Tech',quality:83,pull:1.23,desc:'rozzo · Deep Tech. Глубокий грув и уверенный танцпол.'},
 neonexus:{fee:750,genre:'Hypnotic Techno',quality:90,pull:1.42,desc:'neonexus · Hypnotic Techno. Гипнотический ритм и плотная атмосфера.'},
 vanya:{fee:850,genre:'Raw Techno',quality:92,pull:1.50,desc:'vanya velin · Raw Techno. Жёсткая энергия для пикового времени.'},
 lutanina:{fee:650,genre:'Soulful Techno',quality:88,pull:1.30,desc:'lutanina · Soulful Techno. Мелодии и эмоциональный грув.'},
 zlostniy:{fee:600,genre:'Romantic Techno',quality:85,pull:1.27,desc:'zlostniy · Romantic Techno. Романтичный, атмосферный сет.'},
 lowq:{fee:700,genre:'Jungle',quality:90,pull:1.35,desc:'lowq · Jungle. Ломаные ритмы и энергия рейва.'},
 velvet37:{fee:550,genre:'Future Garage',quality:84,pull:1.20,desc:'velvet 37 · Future Garage. Глубокий бас и ночная меланхолия.'},
 raison:{fee:600,genre:'Sexy Minimal Techno',quality:86,pull:1.29,desc:'Raison · Sexy Minimal Techno. Соблазнительный минимал-грув и плотный клубный ритм.'},
 boriskhodok:{fee:650,genre:'Deep Deep Deep House',quality:87,pull:1.30,desc:'DJ Boris Khodok · Deep Deep Deep House. Глубокий хаус и атмосферный грув.'}
};const TYPES={dj:{name:'DJ · 1×2',cost:1500,color:'#aa64d8'},bar:{name:'Бар · 1×2',cost:1000,color:'#b36e40'},floor:{name:'Танцпол',cost:50,color:'#6349a4'},speaker:{name:'Колонка',cost:400,color:'#363448'},light:{name:'Свет',cost:250,color:'#e278c4'},sofa:{name:'Диван · 1×2',cost:300,color:'#487b7b'},wc:{name:'Туалет · 1×2',cost:800,color:'#7385a5'},plant:{name:'Растение',cost:180,color:'#428b66'},table:{name:'Стол',cost:150,color:'#64606b'},poster:{name:'Постер',cost:120,color:'#e15b98'},rail:{name:'Ограждение',cost:100,color:'#a17b99'},stool:{name:'Табурет',cost:90,color:'#b9788c'},laser:{name:'Лазер',cost:450,color:'#d852d1'}};const SPRITES={"wall": "assets/sprites/sprite_01.png", "floor": "assets/sprites/sprite_02.png", "dj": "assets/sprites/sprite_03.png", "bar": "assets/sprites/sprite_04.png", "speaker": "assets/sprites/sprite_05.png", "light": "assets/sprites/sprite_06.png", "sofa": "assets/sprites/sprite_07.png", "wc": "assets/sprites/sprite_08.png", "plant": "assets/sprites/sprite_09.png", "table": "assets/sprites/sprite_10.png", "person": "assets/sprites/sprite_11.png"};const spriteImages={};for(const [k,src] of Object.entries(SPRITES)){const img=new Image();img.src=src;spriteImages[k]=img;}
const EXTRA_SPRITES={"guest_0_0": "assets/sprites/sprite_12.png", "guest_0_1": "assets/sprites/sprite_13.png", "guest_0_2": "assets/sprites/sprite_14.png", "guest_0_3": "assets/sprites/sprite_15.png", "guest_1_0": "assets/sprites/sprite_16.png", "guest_1_1": "assets/sprites/sprite_17.png", "guest_1_2": "assets/sprites/sprite_18.png", "guest_1_3": "assets/sprites/sprite_19.png", "guest_2_0": "assets/sprites/sprite_20.png", "guest_2_1": "assets/sprites/sprite_21.png", "guest_2_2": "assets/sprites/sprite_22.png", "guest_2_3": "assets/sprites/sprite_23.png", "guest_3_0": "assets/sprites/sprite_24.png", "guest_3_1": "assets/sprites/sprite_25.png", "guest_3_2": "assets/sprites/sprite_26.png", "guest_3_3": "assets/sprites/sprite_27.png", "guest_4_0": "assets/sprites/sprite_28.png", "guest_4_1": "assets/sprites/sprite_29.png", "guest_4_2": "assets/sprites/sprite_30.png", "guest_4_3": "assets/sprites/sprite_31.png", "guest_5_0": "assets/sprites/sprite_32.png", "guest_5_1": "assets/sprites/sprite_33.png", "guest_5_2": "assets/sprites/sprite_34.png", "guest_5_3": "assets/sprites/sprite_35.png", "door": "assets/sprites/sprite_36.png", "poster": "assets/sprites/sprite_37.png", "rail": "assets/sprites/sprite_38.png", "plant2": "assets/sprites/sprite_39.png", "stool": "assets/sprites/sprite_40.png", "laser": "assets/sprites/sprite_41.png"};for(const [k,src] of Object.entries(EXTRA_SPRITES)){let img=new Image();img.src=src;spriteImages[k]=img;}
// Alpha 10: persistent progression per club, reset with New Game.
const LEVEL_XP=[0,100,250,450,700,1000,1400,1900,2500,3300];
const LEVEL_NAMES=['Illegal Basement','Word of Mouth','Local Favorite','Afterhours','Underground Institution','Citywide Buzz','Cult Following','Scene Leader','International Attention','Legendary Venue'];
const UNLOCKS={poster:2,stool:3,plant:5,sofa:3,table:4,light:1,laser:2,rail:5};
const PERKS={music:[{id:'connections',name:'Local Connections',desc:'−5% гонорара DJ',value:.05},{id:'resident',name:'Resident Deal',desc:'Ещё −10% гонорара DJ',value:.10},{id:'lineups',name:'Better Lineups',desc:'+8% гостей',value:.08}],bar:[{id:'happy',name:'Happy Hour',desc:'+5% выручки бара',value:.05},{id:'premium',name:'Premium Drinks',desc:'Ещё +10% выручки бара',value:.10},{id:'management',name:'Bar Management',desc:'−10% себестоимости напитков',value:.10}],community:[{id:'word',name:'Word of Mouth',desc:'+5% гостей',value:.05},{id:'regulars',name:'Regular Crowd',desc:'+10% гостей',value:.10},{id:'cult',name:'Cult Status',desc:'+15% прироста репутации',value:.15}]};
let xp=0,unlockedPerks=[],firstDJs=[],bestAttendance=0,progressTab='music',lastXpGain=0;
function level(){let n=1;for(let i=0;i<LEVEL_XP.length;i++)if(xp>=LEVEL_XP[i])n=i+1;return n}
// Price ceilings grow with club level; revenue, demand and mood formulas stay unchanged.
function priceCaps(){const lv=level();return {ticket:35+3*(lv-1),drink:16+(lv-1)}}
function updatePriceLimits(){
 const caps=priceCaps(),ticket=$('ticketSlider'),drink=$('drinkSlider');
 ticket.max=caps.ticket;drink.max=caps.drink;
 ticketPrice=Math.max(+ticket.min,Math.min(caps.ticket,ticketPrice));
 drinkPrice=Math.max(+drink.min,Math.min(caps.drink,drinkPrice));
 ticket.value=ticketPrice;drink.value=drinkPrice;
 $('ticketVal').textContent='€'+ticketPrice;
 $('drinkVal').textContent='€'+drinkPrice;
 ticket.title='Максимум на уровне '+level()+': €'+caps.ticket;
 drink.title='Максимум на уровне '+level()+': €'+caps.drink;
}
function perk(id){return unlockedPerks.includes(id)}
function bonus(kind){
 const n=count;
 if(kind==='attendance')return Math.min(.3,(n('poster')?0.05:0)+(n('laser')>=2?0.10:0)+(perk('lineups')?.08:0)+(perk('word')?.05:0)+(perk('regulars')?.10:0));
 if(kind==='bar')return Math.min(.35,Math.min(3,Math.floor(n('stool')/2))*.03+(n('sofa')&&n('table')&&n('plant')?0.05:0)+(perk('happy')?.05:0)+(perk('premium')?.10:0));
 if(kind==='mood')return n('light')>=2?8:0;
 if(kind==='djDiscount')return (perk('connections')?.05:0)+(perk('resident')?.10:0);
 return 0;
}
function djFee(){return Math.round(DJS[chosenDJ].fee*(1-bonus('djDiscount')))}
function awardXp(amount){if(amount<=0)return;const old=level();xp+=amount;lastXpGain=amount;const next=level();if(next>old){log('LEVEL UP! Уровень '+next+' — '+LEVEL_NAMES[next-1]+'. Новые объекты и очко перка!');tools()}updateProgress()}
function progressionRequirements(){return [['DJ-стойка',count('dj'),1],['Колонки',count('speaker'),2],['Танцпол',count('floor'),6],['Бар',count('bar'),1]]}
function updateProgress(){
 updatePriceLimits();
 updateExpansionPanel();
 const el=$('progressStats');if(!el)return;
 const lv=level(),next=LEVEL_XP[lv]??LEVEL_XP[9],prev=LEVEL_XP[lv-1];
 const ratio=lv===10?100:Math.min(100,Math.round((xp-prev)/(next-prev)*100));
 el.innerHTML='<div class="progress-title">LVL '+lv+' · '+LEVEL_NAMES[lv-1]+'</div><div class="xp-track"><div class="xp-fill" style="width:'+ratio+'%"></div></div><div class="progress-sub">'+xp+' XP'+(lv<10?' / '+next+' XP':' · MAX LEVEL')+' · Свободно очков: '+Math.max(0,lv-1-unlockedPerks.length)+'</div>';
 const label=$('levelHeader');if(label)label.textContent='LVL '+lv;
 const tabs=$('perkTabs');if(tabs&&!tabs.childElementCount){for(const [key,name] of [['music','Музыка'],['bar','Бар'],['community','Комьюнити']]){const b=document.createElement('button');b.textContent=name;b.dataset.tree=key;b.onclick=()=>{progressTab=key;renderPerks()};tabs.append(b)}}
 renderPerks();
}
const EXPANSION_COST=15000;
function updateExpansionPanel(){
 const el=$('expansionPanel');if(!el)return;
 const expanded=N===22,lv=level(),cashReady=money>=EXPANSION_COST,repReady=rep>=70,levelReady=lv>=5;
 el.hidden=false;el.classList.toggle('expansion-complete',expanded);
 const description=$('expansionDescription'),button=$('expandClub');
 if(description)description.textContent=expanded?'Новый зал открыт! 22×22 клетки, почти вдвое больше пространства для вечеринок.':'Твоя следующая большая цель: арендуй соседнее помещение и увеличь клуб с 16×16 до 22×22 клеток.';
 const cash=$('expansionCash'),reputation=$('expansionRep'),levelLabel=$('expansionLevel');
 if(cash)cash.textContent='€'+Math.floor(money).toLocaleString('ru')+' / €15 000';
 if(reputation)reputation.textContent=Math.round(rep)+' / 70';
 if(levelLabel)levelLabel.textContent='LVL '+lv+' / 5';
 for(const [id,ratio] of [['expansionCashBar',money/EXPANSION_COST],['expansionRepBar',rep/70],['expansionLevelBar',lv/5]]){
  const bar=$(id);if(bar)bar.style.width=Math.min(100,Math.max(0,ratio*100))+'%';
 }
 for(const [id,ok] of [['expansionCashCheck',cashReady],['expansionRepCheck',repReady],['expansionLevelCheck',levelReady]]){
  const mark=$(id);if(mark)mark.textContent=ok?'✓':'○';
 }
 if(button){
  button.hidden=expanded;
  button.disabled=running||people.length>0||!levelReady||!repReady||!cashReady;
  button.textContent=expanded?'РАСШИРЕНО':button.disabled?'🔒 РАСШИРИТЬ КЛУБ · €15 000':'✦ РАСШИРИТЬ КЛУБ · €15 000';
 }
 const note=$('expansionHint');
 if(note)note.textContent=expanded?'Цель достигнута. Время строить новый танцпол!':running||people.length?'Дождись окончания вечеринки и ухода гостей.':!levelReady||!cashReady||!repReady?'Выполни все три условия, чтобы открыть расширение.':'Все условия выполнены! Можно расширяться.';
}
function expandClub(){
 if(N!==16||level()<5||rep<70||money<EXPANSION_COST||running||people.length)return;
 if(!confirm('Расширить клуб до 22×22 за €15 000? Планировка и оборудование сохранятся.'))return;
 undoStack.length=0;const old=map,oldRot=rotations,shift=3;
 N=22;
 map=Array.from({length:N},()=>Array(N).fill(null));
 for(let y=0;y<N;y++)for(let x=0;x<N;x++)if(!x||!y||x===N-1||y===N-1)map[y][x]='wall';
 for(let y=1;y<15;y++)for(let x=1;x<15;x++)if(old[y][x]&&old[y][x]!=='wall')map[y+shift][x+shift]=old[y][x];
 // Rebuild occupied markers using shifted anchors, including multi-cell furniture.
 for(let y=1;y<N-1;y++)for(let x=1;x<N-1;x++)if(typeof map[y][x]==='string'&&map[y][x].startsWith('occupied:')){
  const parts=map[y][x].split(':');map[y][x]='occupied:'+(+parts[1]+shift)+':'+(+parts[2]+shift);
 }
 rotations={};
 for(const [key,value] of Object.entries(oldRot)){const [x,y]=key.split(',').map(Number);rotations[(x+shift)+','+(y+shift)]=value}
 map[N-1][10]=null;map[N-1][11]=null;
 money-=EXPANSION_COST;
 updateUI();updateProgress();log('Новый зал открыт! Площадь 22×22. Время строить большой рейв.');
}
function renderPerks(){const el=$('perkList');if(!el)return;document.querySelectorAll('[data-tree]').forEach(b=>b.classList.toggle('active',b.dataset.tree===progressTab));const list=PERKS[progressTab];el.replaceChildren();for(let i=0;i<list.length;i++){const p=list[i],owned=perk(p.id),prior=i===0||perk(list[i-1].id),points=level()-1-unlockedPerks.length;const b=document.createElement('button');b.className='perk-item'+(owned?' owned':'');b.disabled=owned||!prior||points<1;b.innerHTML='<strong>'+(owned?'✓ ':!prior?'🔒 ':'✦ ')+p.name+'</strong><small>'+p.desc+'</small>';b.onclick=()=>{if(perk(p.id)||!prior||level()-1-unlockedPerks.length<1)return;unlockedPerks.push(p.id);updateProgress();updateUI();log('Открыт перк: '+p.name)};el.append(b)}}
let clubName='THE BASEMENT';let night=1,ticketPrice=15,drinkPrice=7,chosenDJ='rozzo',totalMood=70;let map=[],people=[],money=10000,rep=50,selected='floor',running=false,paused=false,speed=1,elapsed=0,spawnTime=0,revTickets=0,revBar=0,expenses=0,served=0,last=0,zoom=1,panX=0,panY=0,hover=null,drag=null,finished=false;const rnd=(a,b)=>a+Math.random()*(b-a);const formatEuro=value=>'€'+(Math.round((value+Number.EPSILON)*100)/100).toFixed(2);function log(t){$('log').textContent=t}function reset(){undoStack.length=0;N=16;xp=0;unlockedPerks=[];firstDJs=[];bestAttendance=0;lastXpGain=0;progressTab='music';rotations={};map=Array.from({length:N},()=>Array(N).fill(null));for(let y=0;y<N;y++)for(let x=0;x<N;x++)if(x===0||y===0||x===N-1||y===N-1)map[y][x]='wall';map[N-1][N/2-1]=null;map[N-1][N/2]=null;people=[];money=10000;rep=50;night=1;running=false;paused=false;window.dispatchEvent(new Event('nightshift:ended'));finished=false;speed=1;elapsed=0;spawnTime=0;revTickets=0;revBar=0;expenses=0;served=0;selected='floor';ticketPrice=15;drinkPrice=7;updatePriceLimits();updateClubName();updateUI();log('Клуб готов к строительству. Начни с DJ, бара и танцпола.')}function cleanClubName(name){return String(name||'').trim().replace(/\s+/g,' ').slice(0,32)||'THE BASEMENT'}
function updateClubName(){document.querySelectorAll('[data-club-name]').forEach(el=>el.textContent=clubName)}
function setClubName(name){clubName=cleanClubName(name);updateClubName();try{localStorage.setItem('nightshift-club-name',clubName)}catch(e){}}
function count(type){return map.flat().filter(x=>x===type).length}function tools(){let el=$('tools');el.innerHTML='';for(let [key,v] of Object.entries(TYPES)){let b=document.createElement('button');b.innerHTML=(key!=='erase'?'<img class="tool-art" src="assets/club/'+key+'.webp" alt="" loading="lazy">':'')+'<span>'+v.name+'</span><small>€'+v.cost+'</small>';b.dataset.type=key;const needed=UNLOCKS[key]||1;if(level()<needed){b.classList.add('tool-locked');b.title='Откроется на LVL '+needed;b.innerHTML+='<em>🔒 LVL '+needed+'</em>';b.disabled=true}b.onclick=()=>{if(level()<needed)return;selected=key;updateUI()};el.append(b)}let del=document.createElement('button');del.textContent='Ластик';del.dataset.type='erase';del.onclick=()=>{selected='erase';updateUI()};el.append(del)}function updateUI(){updateChecklist();updateExpansionPanel();$('night').textContent=night;let active=people.filter(p=>!p.leaving);totalMood=active.length?active.reduce((s,p)=>s+p.mood,0)/active.length:70;$('mood').textContent=Math.round(totalMood)+'%';$('moodSide').textContent=Math.round(totalMood)+'%';$('dancing').textContent=active.filter(p=>p.state==='dance').length;$('atbar').textContent=active.filter(p=>p.state==='bar').length;$('resting').textContent=active.filter(p=>p.state==='rest').length;$('money').textContent='€'+Math.round(money).toLocaleString('ru');$('guests').textContent=people.filter(p=>!p.leaving).length+' / '+Math.min(120,50+count('floor')*3);$('rep').textContent=Math.round(rep);let mins=Math.min(360,Math.floor(elapsed*3));$('clock').textContent=String((22+Math.floor(mins/60))%24).padStart(2,'0')+':'+String(mins%60).padStart(2,'0');$('mode').textContent=running?'Ночная смена':'Строительство';$('cost').textContent=TYPES[selected]?'€'+TYPES[selected].cost:'—';$('tickets').textContent=formatEuro(revTickets);$('barIncome').textContent=formatEuro(revBar);$('expenses').textContent=formatEuro(expenses);$('profit').textContent=formatEuro(revTickets+revBar-expenses);document.querySelectorAll('[data-type]').forEach(b=>b.classList.toggle('active',b.dataset.type===selected));$('start').disabled=running;$('pause').disabled=!running;$('speed').disabled=!running;$('pause').textContent=paused?'▶ ПРОДОЛЖИТЬ':'⏸ ПАУЗА';$('speed').textContent='⏩ СКОРОСТЬ ×'+speed}
function iso(x,y){return {x:(x-y)*TILE_W/2,y:(x+y)*TILE_H/2}}function project(x,y){let p=iso(x,y);return {x:canvas.width/2+panX+p.x*zoom,y:canvas.height*.18+panY+p.y*zoom}}function polygon(points,fill,stroke){ctx.beginPath();points.forEach((p,i)=>i?ctx.lineTo(p.x,p.y):ctx.moveTo(p.x,p.y));ctx.closePath();ctx.fillStyle=fill;ctx.fill();if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=1;ctx.stroke()}}function diamond(x,y,color){let p=project(x,y),w=TILE_W*zoom/2,h=TILE_H*zoom/2;polygon([{x:p.x,y:p.y-h},{x:p.x+w,y:p.y},{x:p.x,y:p.y+h},{x:p.x-w,y:p.y}],color,'#343044')}function block(x,y,height,color){let p=project(x,y),w=TILE_W*zoom*.40,h=TILE_H*zoom*.40,top=height*zoom;polygon([{x:p.x,y:p.y-h-top},{x:p.x+w,y:p.y-top},{x:p.x,y:p.y+h-top},{x:p.x-w,y:p.y-top}],color,'#181521');polygon([{x:p.x-w,y:p.y-top},{x:p.x,y:p.y+h-top},{x:p.x,y:p.y+h},{x:p.x-w,y:p.y}], '#30253c');polygon([{x:p.x,y:p.y+h-top},{x:p.x+w,y:p.y-top},{x:p.x+w,y:p.y},{x:p.x,y:p.y+h}],'#1d1a29')}
function drawSprite(kind,x,y,scale=1){let img=spriteImages[kind];if(!img||!img.complete)return;let p=project(x,y);let size=66*zoom*scale;ctx.drawImage(img,p.x-size/2,p.y-size*.77,size,size)}
let lightingEnabled=true,particlesEnabled=true,fxParticles=[],frameNo=0;
function glow(x,y,r,color){let g=ctx.createRadialGradient(x,y,0,x,y,r);g.addColorStop(0,color);g.addColorStop(1,'#00000000');ctx.fillStyle=g;ctx.fillRect(x-r,y-r,2*r,2*r)}
function personSprite(p){let frame=p.state==='dance'?Math.floor(elapsed*5+p.x*2)%4:p.path.length?Math.floor(elapsed*7+p.y*2)%4:0;let img=spriteImages['guest_'+(p.variant??0)+'_'+frame];if(!img?.complete)return;let pt=project(p.x,p.y),sz=36*zoom;let bob=p.state==='dance'?Math.sin(elapsed*10+p.x*3)*2*zoom:0;ctx.drawImage(img,pt.x-sz/2,pt.y-sz*.85+bob,sz,sz*1.5);
 if(p.state==='dance'&&running&&Math.sin(elapsed*4+p.x*3+p.y)>0.93){
 ctx.fillStyle='#ff75d8';ctx.fillRect(pt.x+sz*.3,pt.y-sz*.85+bob,3*zoom,3*zoom);
 }}
function drawFX(){if(!running||paused)return;frameNo++;if(particlesEnabled&&frameNo%5===0&&fxParticles.length<80){let floors=[];for(let y=1;y<N-1;y++)for(let x=1;x<N-1;x++)if(map[y][x]==='floor')floors.push({x,y});if(floors.length){let p=floors[Math.floor(Math.random()*floors.length)],pt=project(p.x,p.y);fxParticles.push({x:pt.x+rnd(-15,15)*zoom,y:pt.y-rnd(0,22)*zoom,life:1,color:Math.random()>.5?'#e94dbd':'#69baff'})}}fxParticles=fxParticles.filter(p=>p.life>0);for(let p of fxParticles){p.life-=.012*speed;p.y-=.18*speed;ctx.globalAlpha=Math.max(0,p.life)*.7;ctx.fillStyle=p.color;ctx.fillRect(p.x,p.y,Math.max(2,3*zoom),Math.max(2,3*zoom))}ctx.globalAlpha=1}
function drawAtmosphere(){
 if(!lightingEnabled||!running)return;
 const t=elapsed*2.2;
 ctx.save();ctx.globalCompositeOperation='screen';
 for(let y=1;y<N-1;y++)for(let x=1;x<N-1;x++){
  const kind=map[y][x];if(kind!=='dj'&&kind!=='light'&&kind!=='laser')continue;
  const p=project(x,y),originY=p.y-34*zoom;
  const palette=kind==='dj'?['#8544ff','#3db9ff']:kind==='laser'?['#ff36ac','#a73dff']:['#ff57ca','#4b8bff'];
  for(let k=0;k<2;k++){
   const dx=Math.sin(t+k*2.4+x)*95*zoom,dy=(80+Math.cos(t*.8+k+y)*30)*zoom;
   let gradient=ctx.createLinearGradient(p.x,originY,p.x+dx,originY+dy);
   gradient.addColorStop(0,palette[k]+'70');gradient.addColorStop(1,palette[k]+'00');
   ctx.fillStyle=gradient;ctx.beginPath();ctx.moveTo(p.x,originY);
   ctx.lineTo(p.x+dx-24*zoom,originY+dy);ctx.lineTo(p.x+dx+24*zoom,originY+dy);
   ctx.closePath();ctx.fill();
  }
 }
 ctx.restore();
}
function drawClubSigns(){
 for(let y=1;y<N-1;y++)for(let x=1;x<N-1;x++){
  let kind=map[y][x];if(!['dj','bar','wc','sofa'].includes(kind))continue;
  let p=project(x,y);
  ctx.save();ctx.font=`bold ${Math.max(8,10*zoom)}px monospace`;ctx.textAlign='center';
  ctx.shadowBlur=12*zoom;ctx.shadowColor=kind==='dj'?'#d54bff':'#5bdeff';
  ctx.fillStyle=kind==='dj'?'#ff85e9':'#8be9ff';
  ctx.fillText(kind==='dj'?'LIVE':kind==='bar'?'BAR':kind==='wc'?'WC':'CHILL',p.x,p.y-48*zoom);
  ctx.restore();
 }
}
function render(){} 
// Furniture transforms are stored independently so old saves remain compatible.
let rotations={};
const key=(x,y)=>x+','+y;
const SIZES={dj:2,bar:2,sofa:2,wc:2};
function footprint(type,x,y,rot=0){const n=SIZES[type]||1;const d=[[0,1],[1,0],[0,-1],[-1,0]][((rot%4)+4)%4];return Array.from({length:n},(_,i)=>({x:x+d[0]*i,y:y+d[1]*i}))}
function anchor(x,y){const v=map[y]?.[x];if(typeof v==='string'&&v.startsWith('occupied:')){const parts=v.split(':');return {x:+parts[1],y:+parts[2]}}if(v==='dj_back'){for(const [dx,dy] of [[0,-1],[-1,0],[0,1],[1,0]]){const ax=x+dx,ay=y+dy;if(map[ay]?.[ax]==='dj'&&footprint('dj',ax,ay,rotations[key(ax,ay)]||0).some(c=>c.x===x&&c.y===y))return {x:ax,y:ay}}}return {x,y}}
function occupiedCells(x,y){const a=anchor(x,y),t=map[a.y]?.[a.x];return footprint(t,a.x,a.y,rotations[key(a.x,a.y)]||0)}
function validCells(cells,ignore=[]){return cells.every(c=>c.x>0&&c.y>0&&c.x<N-1&&c.y<N-1&&(!map[c.y][c.x]||ignore.some(i=>i.x===c.x&&i.y===c.y)))}
const undoStack=[];
function rememberEdit(){undoStack.push({map:map.map(row=>row.slice()),rotations:{...rotations},money});if(undoStack.length>40)undoStack.shift()}
function undoEdit(){if(running||!undoStack.length)return false;const previous=undoStack.pop();map=previous.map;rotations=previous.rotations;money=previous.money;updateUI();log('Последнее действие отменено.');return true}
function observeMode(){selected=null;updateUI();log('Режим наблюдения: перетаскивай сцену для вращения.')}
function writeObject(type,x,y,rot=0){const cells=footprint(type,x,y,rot);cells.forEach((c,i)=>map[c.y][c.x]=i?`occupied:${x}:${y}`:type);rotations[key(x,y)]=rot}
function moveObject(x,y,nx,ny){if(running)return false;const a=anchor(x,y),type=map[a.y]?.[a.x];if(!TYPES[type]||type==='floor'||type==='poster')return false;const old=occupiedCells(a.x,a.y),rot=rotations[key(a.x,a.y)]||0,next=footprint(type,nx,ny,rot);if(!validCells(next,old))return false;rememberEdit();old.forEach(c=>map[c.y][c.x]=null);delete rotations[key(a.x,a.y)];writeObject(type,nx,ny,rot);updateUI();return true}
function rotateObject(x,y){if(running)return false;const a=anchor(x,y),type=map[a.y]?.[a.x];if(!TYPES[type]||type==='floor'||type==='poster')return false;const old=occupiedCells(a.x,a.y),rot=((rotations[key(a.x,a.y)]||0)+1)%4,next=footprint(type,a.x,a.y,rot);if(!validCells(next,old))return false;rememberEdit();old.forEach(c=>map[c.y][c.x]=null);writeObject(type,a.x,a.y,rot);updateUI();return true}
function place(x,y,erase=false){
 if(!erase&&selected===null)return;
 if(running||x<0||y<0||x>=N||y>=N)return;
 const type=erase?'erase':selected;
 const boundary=x===0||y===0||x===N-1||y===N-1;
 if(boundary){
  // Posters are wall replacements: one poster occupies one perimeter segment.
  // Preserve the two-cell main entrance and the other fixed walls.
  if(y===N-1&&(x===N/2-1||x===N/2))return;
  if(type==='poster'&&level()<2){log('Постер откроется на LVL 2');return}
  if(type==='poster'&&map[y][x]==='wall'){
   if(money<TYPES.poster.cost){log('Недостаточно денег.');return}
   rememberEdit();map[y][x]='poster';money-=TYPES.poster.cost;updateUI();
  }else if(type==='erase'&&map[y][x]==='poster'){
   rememberEdit();map[y][x]='wall';money+=TYPES.poster.cost;updateUI();
  }
  return;
 }
 if(type==='poster'){log('Постер устанавливается на стену по периметру клуба.');return}

 if(type==='erase'){const a=anchor(x,y),t=map[a.y]?.[a.x];if(TYPES[t]){rememberEdit();occupiedCells(a.x,a.y).forEach(c=>map[c.y][c.x]=null);money+=TYPES[t].cost;delete rotations[key(a.x,a.y)]}}
 else if(TYPES[type]){if(level()<(UNLOCKS[type]||1)){log('Откроется на LVL '+UNLOCKS[type]);return}const cells=footprint(type,x,y);if(!validCells(cells))log('Нужно '+cells.length+' свободных клеток подряд.');else if(money<TYPES[type].cost)log('Недостаточно денег.');else{rememberEdit();writeObject(type,x,y);money-=TYPES[type].cost}}updateUI()}
function available(){return count('dj')>=1&&count('speaker')>=2&&count('bar')>=1&&count('floor')>=6}function nearest(type,p){let best=null,dist=Infinity;for(let y=1;y<N-1;y++)for(let x=1;x<N-1;x++)if(map[y][x]===type){let d=Math.hypot(x-p.x,y-p.y);if(d<dist){dist=d;best={x,y}}}return best}function walkableCell(x,y){return x>=1&&y>=1&&x<N-1&&y<N-1&&(!map[y][x]||map[y][x]==='floor'||map[y][x]==='door')}
function clearForGuest(x,y){const radius=.28;return [[0,0],[radius,0],[-radius,0],[0,radius],[0,-radius],[radius,radius],[radius,-radius],[-radius,radius],[-radius,-radius]].every(([dx,dy])=>walkableCell(Math.round(x+dx),Math.round(y+dy)))}
function path(start,target){
 if(!target)return[];
 const origin={x:Math.round(start.x),y:Math.round(start.y)};
 const dest={x:Math.round(target.x),y:Math.round(target.y)};
 if(!walkableCell(dest.x,dest.y))return[];
 const key=(x,y)=>x+','+y;
 const queue=[origin],visited=new Set([key(origin.x,origin.y)]),prev=new Map();
 for(let head=0;head<queue.length;head++){
  const a=queue[head],k=key(a.x,a.y);
  if(a.x===dest.x&&a.y===dest.y){
   const result=[];let current=a,currentKey=k;
   while(prev.has(currentKey)){result.unshift({x:current.x,y:current.y});current=prev.get(currentKey);currentKey=key(current.x,current.y)}
   return result;
  }
  for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){
   const x=a.x+dx,y=a.y+dy,nk=key(x,y);
   if(visited.has(nk)||!walkableCell(x,y))continue;
   visited.add(nk);prev.set(nk,a);queue.push({x,y});
  }
 }
 return[];
}
function danceTarget(p){
 const booths=[];for(let y=1;y<N-1;y++)for(let x=1;x<N-1;x++)if(map[y][x]==='dj')booths.push({x,y});
 const floors=[];
 for(let y=1;y<N-1;y++)for(let x=1;x<N-1;x++)if(map[y][x]==='floor'&&clearForGuest(x,y)){
  const route=path(p,{x,y});if(!route.length&&Math.hypot(p.x-x,p.y-y)>.35)continue;
  const distance=booths.length?Math.min(...booths.map(b=>Math.hypot(b.x-x,b.y-y))):5;
  const crowd=people.filter(q=>q!==p&&!q.leaving&&q.state==='dance'&&q.target&&Math.hypot(q.target.x-x,q.target.y-y)<.6).length;
  floors.push({x,y,weight:1/(1+distance*.28+crowd*2)});
 }
 if(!floors.length)return null;
 let sum=floors.reduce((n,f)=>n+f.weight,0),pick=Math.random()*sum;
 for(const f of floors){pick-=f.weight;if(pick<=0)return{x:f.x,y:f.y}}
 return{x:floors[0].x,y:floors[0].y};
}
function interactionTarget(type,p){
 let best=null,score=Infinity;
 for(let y=1;y<N-1;y++)for(let x=1;x<N-1;x++)if(map[y][x]===type){
  const cells=occupiedCells(x,y);
  for(const c of cells)for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){
   const nx=c.x+dx,ny=c.y+dy;
   if(nx<1||ny<1||nx>=N-1||ny>=N-1)continue;
   if(map[ny][nx]&&map[ny][nx]!=='floor')continue;
   const d=Math.hypot(nx-p.x,ny-p.y);
   if(d<score){score=d;best={x:nx,y:ny}}
  }
 }
 return best;
}
function exitGuest(p){
 p.leaving=true;p.state='exit';p.target={x:N/2-1,y:N-2};p.wait=0;
 // A guest may be standing on a tile that became occupied by furniture.
 // Start route finding at the closest reachable free cell instead.
 const sx=Math.round(p.x),sy=Math.round(p.y);
 if(!walkableCell(sx,sy)){
  const candidates=[];
  for(let y=1;y<N-1;y++)for(let x=1;x<N-1;x++)if(walkableCell(x,y)){
   const route=path({x,y},p.target);
   if(route.length||x===N/2-1&&y===N-2)candidates.push({x,y,route,d:Math.hypot(x-p.x,y-p.y)});
  }
  candidates.sort((a,b)=>a.d-b.d);
  if(candidates.length){const c=candidates[0];p.path=[{x:c.x,y:c.y},...c.route];return}
 }
 p.path=path(p,p.target);
}
function choose(p){
 if(p.leaving)return;
 const options=[];
 if(p.thirst>52&&count('bar'))options.push(['bar',interactionTarget('bar',p)]);
 if(p.energy<20&&count('sofa'))options.push(['rest',interactionTarget('sofa',p)]);
 options.push(['dance',danceTarget(p)]);
 for(const [state,target] of options){
  if(!target||!clearForGuest(target.x,target.y))continue;
  const route=path(p,target);
  if(!route.length&&Math.hypot(p.x-target.x,p.y-target.y)>.35)continue;
  p.state=state;p.target=target;p.path=route;
  p.wait=state==='dance'?rnd(16,30):state==='bar'?rnd(4,7):rnd(7,12);
  return;
 }
 p.state='idle';p.target={x:Math.round(p.x),y:Math.round(p.y)};p.path=[];p.wait=rnd(3,6);
}
function spawn(){if(people.filter(p=>!p.leaving).length>=Math.min(120,50+count('floor')*3)||served>=125)return;let p={x:N/2-1,y:N-2,thirst:rnd(20,48),energy:rnd(60,100),mood:rnd(50,90),variant:Math.floor(rnd(0,5)),color:['#d9558d','#5da4d4','#b7a0d5','#d9a74c','#68aa98'][Math.floor(rnd(0,5))],state:'enter',path:[],wait:0,leaving:false,spent:false};people.push(p);served++;revTickets+=ticketPrice;money+=ticketPrice;choose(p)}function simulate(dt){if(paused&&running)return;if(!running){if(people.length){const step=Math.min(dt,.05)*.85;const exitX=N/2-1,exitY=N-2;for(const p of people){if(!p.leaving)exitGuest(p);if(!p.path.length&&Math.hypot(p.x-(N/2-1),p.y-(N-2))>.25)exitGuest(p);if(p.path.length){const a=p.path[0],dx=a.x-p.x,dy=a.y-p.y,d=Math.hypot(dx,dy);if(d<.08){p.x=a.x;p.y=a.y;p.path.shift()}else{p.x+=dx/d*Math.min(step,d);p.y+=dy/d*Math.min(step,d)}}}people=people.filter(p=>p.path.length||Math.hypot(p.x-exitX,p.y-exitY)>.25);
 // Remove guests who cannot reach the exit, instead of leaving them stuck indefinitely.
 for(const p of people){p.exitStuck=(p.exitStuck||0)+dt;if(Math.hypot(p.x-(p.exitLastX??p.x),p.y-(p.exitLastY??p.y))>.12){p.exitStuck=0;p.exitLastX=p.x;p.exitLastY=p.y}}
 people=people.filter(p=>p.exitStuck<12);
 }return}dt*=speed;elapsed+=dt;spawnTime+=dt;let density=Math.max(.2,Math.min(1.5,(rep/65)*(1+count('floor')/30)*DJS[chosenDJ].pull*(1+bonus('attendance'))*(1-Math.max(0,ticketPrice-15)*.025)));if(spawnTime>Math.max(.7,3/density)){spawnTime=0;spawn()}for(let p of people){p.thirst+=dt*1.05;p.energy-=dt*(p.state==='dance'&&!p.path.length?.7:.42);p.mood-=dt*(.08+Math.max(0,ticketPrice-20)*.02);p.mood+=dt*(DJS[chosenDJ].quality-65)*.008+dt*bonus('mood')*.008;p.mood=Math.min(100,p.mood);if(p.leaving&&p.path.length===0&&Math.hypot(p.x-(N/2-1),p.y-(N-2))>.25){exitGuest(p)}if(p.path.length){let a=p.path[0],dx=a.x-p.x,dy=a.y-p.y,d=Math.hypot(dx,dy);if(d<.07){p.x=a.x;p.y=a.y;p.path.shift()}else{let step=Math.min(d,dt*.85),nx=p.x+dx/d*step,ny=p.y+dy/d*step;const walkable=(xx,yy)=>walkableCell(Math.round(xx),Math.round(yy));if(clearForGuest(nx,ny)){p.x=nx;p.y=ny}else{p.path=path(p,p.leaving?{x:N/2-1,y:N-2}:p.target||{x:N/2-1,y:N-3});if(!p.path.length&&!p.leaving)choose(p)}}}else{p.wait-=dt;if(p.wait<=0){if(p.leaving){p.wait=1;continue}if(p.state==='bar'){p.thirst=Math.max(0,p.thirst-65);if(!p.spent){const sale=Math.round(drinkPrice*(1+bonus('bar'))*100)/100;revBar+=sale;money+=Math.max(0,sale-(perk('management')?1.8:2));p.spent=true}}else if(p.state==='rest'){p.energy=Math.min(100,p.energy+40)}else if(p.state==='dance'){p.energy-=8;p.mood=Math.min(100,p.mood+5)}p.spent=false;if(p.energy<=3||p.mood<=10||p.thirst>=105){exitGuest(p)}else choose(p)}}}people=people.filter(p=>!(p.leaving&&p.path.length===0&&Math.hypot(p.x-(N/2-1),p.y-(N-2))<.25));if(elapsed>=120){const nightProfit=revTickets+revBar-expenses;const nightMood=totalMood;const capacity=Math.min(120,50+count('floor')*3);const wasNewDJ=!firstDJs.includes(chosenDJ);const attendanceRecord=served>bestAttendance;const earned=20+(nightProfit>0?10:0)+(served>=capacity*.8?10:0)+(nightMood>85?10:0)+(wasNewDJ?15:0)+(attendanceRecord?15:0);if(wasNewDJ)firstDJs.push(chosenDJ);bestAttendance=Math.max(bestAttendance,served);running=false;window.dispatchEvent(new Event('nightshift:ended'));finished=true;rep=Math.max(0,Math.min(100,rep+(served>=20?Math.round((totalMood-50)/10)*(perk('cult')?1.15:1):-3)));awardXp(earned);log('Ночь окончена! '+served+' гостей · прибыль €'+Math.round(nightProfit)+' · +'+earned+' XP. '+(level()>1?'Уровень '+level()+'.':'') );for(const p of people)exitGuest(p);night++;updateUI()}}function updateChecklist(){
 const panel=$('setupPanel'),el=$('readiness');if(!el||!panel)return;
 // Show only unmet, mandatory requirements. Optional lights and toilets
 // are not prerequisites for opening and therefore do not block dismissal.
 const checks=progressionRequirements();
 const missing=checks.filter(([,current,required])=>current<required);
 panel.hidden=missing.length===0;
 if(missing.length){
  el.innerHTML=missing.map(([name,current,required])=>'<div class="ready-row"><span>○ '+name+'</span><b>'+current+'/'+required+'</b></div>').join('');
 }else{el.replaceChildren()}
 const button=$('start');if(button&&!running)button.disabled=!available();
}
function start(){if(!available()){log('Для открытия нужны: DJ-стойка, 2 колонки, бар и 6 клеток танцпола.');return}const nightCost=350+djFee()+Math.round(count('light')*10);if(money<nightCost){log('Недостаточно средств для вечеринки: нужно €'+nightCost+', доступно €'+money+'.');return}running=true;paused=false;finished=false;elapsed=0;spawnTime=0;revTickets=0;revBar=0;served=0;expenses=350+djFee()+Math.round(count('light')*10);money-=expenses;log('22:00 — двери открыты. Первые гости уже подходят!');window.dispatchEvent(new Event('nightshift:started'));updateUI()}$('lightsToggle').onclick=()=>{lightingEnabled=!lightingEnabled;$('lightsToggle').textContent='✦ СВЕТ: '+(lightingEnabled?'ON':'OFF')};$('fxToggle').onclick=()=>{particlesEnabled=!particlesEnabled;$('fxToggle').textContent='✧ ЭФФЕКТЫ: '+(particlesEnabled?'ON':'OFF');if(!particlesEnabled)fxParticles=[]};function showClubNameDialog(){const dialog=$('nameDialog');$('clubNameInput').value=clubName;dialog.hidden=false;setTimeout(()=>$('clubNameInput').focus(),0)}
$('enterGame').onclick=()=>{$('splash').remove();if(!localStorage.getItem('nightshift-club-name'))showClubNameDialog()};
$('clubNameForm').onsubmit=e=>{e.preventDefault();setClubName($('clubNameInput').value);$('nameDialog').hidden=true};
$('renameClub').onclick=showClubNameDialog;$('ticketSlider').oninput=e=>{ticketPrice=+e.target.value;updatePriceLimits()};$('drinkSlider').oninput=e=>{drinkPrice=+e.target.value;updatePriceLimits()};$('djSelect').onchange=e=>{chosenDJ=e.target.value;$('djInfo').textContent=DJS[chosenDJ].desc};$('start').onclick=start;
$('pause').onclick=()=>{paused=!paused;window.dispatchEvent(new CustomEvent('nightshift:pause',{detail:{paused}}));updateUI()};$('speed').onclick=()=>{speed=speed===1?2:speed===2?4:1;updateUI()};$('save').onclick=()=>{localStorage.setItem('nightshift-v04',JSON.stringify({map,money,rep,night,ticketPrice,drinkPrice,chosenDJ,clubName,rotations,xp,unlockedPerks,firstDJs,bestAttendance}));log('Клуб сохранён в этом браузере.')};$('reset').onclick=()=>{if(confirm('Начать новую игру? Клуб, XP, уровни и все перки будут сброшены.')){localStorage.removeItem('nightshift-v04');localStorage.removeItem('nightshift-v03');localStorage.removeItem('nightshift-v02');localStorage.removeItem('nightshift-club-name');clubName='THE BASEMENT';reset();tools();updateProgress();showClubNameDialog()}};tools();reset();updateProgress();$('expandClub')?.addEventListener('click',expandClub);try{clubName=cleanClubName(localStorage.getItem('nightshift-club-name')||clubName);updateClubName()}catch(e){}try{let s=JSON.parse((localStorage.getItem('nightshift-v04')||localStorage.getItem('nightshift-v03')||localStorage.getItem('nightshift-v02')));if(s&&[16,22].includes(s.map?.length)){N=s.map.length;clubName=cleanClubName(s.clubName||localStorage.getItem('nightshift-club-name')||clubName);updateClubName();map=s.map;for(const row of map)for(let i=0;i<row.length;i++)if(row[i]==='plant2')row[i]='plant';const removedDoors=map.flat().filter(v=>v==='door').length;for(const row of map)for(let i=0;i<row.length;i++)if(row[i]==='door')row[i]=null;rotations=s.rotations||{};
 // Alpha 9.1 migration: a bar now occupies two cells instead of three.
 // Clear old occupancy markers and rebuild footprints using current rules.
 for(let yy=1;yy<N-1;yy++)for(let xx=1;xx<N-1;xx++){
  if(typeof map[yy][xx]==='string'&&map[yy][xx].startsWith('occupied:'))map[yy][xx]=null;
 }
// Rebuild all furniture collision cells from saved anchors and rotations.
for(let yy=1;yy<N-1;yy++)for(let xx=1;xx<N-1;xx++){
 const kind=map[yy][xx];
 if(!['dj','bar','sofa','wc'].includes(kind))continue;
 const cells=footprint(kind,xx,yy,rotations[key(xx,yy)]||0);
 if(cells.slice(1).every(c=>c.x>0&&c.y>0&&c.x<N-1&&c.y<N-1&&(!map[c.y][c.x]||map[c.y][c.x]==='dj_back')))
  cells.slice(1).forEach(c=>map[c.y][c.x]=`occupied:${xx}:${yy}`);
}
money=s.money+removedDoors*250;xp=Math.max(0,Number(s.xp)||0);unlockedPerks=Array.isArray(s.unlockedPerks)?s.unlockedPerks.filter(id=>Object.values(PERKS).flat().some(p=>p.id===id)):[];firstDJs=Array.isArray(s.firstDJs)?s.firstDJs:[];bestAttendance=Number(s.bestAttendance)||0;rep=s.rep;night=s.night||1;ticketPrice=s.ticketPrice||15;drinkPrice=s.drinkPrice||7;chosenDJ=({resident:'rozzo',maya:'lutanina',kalt:'vanya'}[s.chosenDJ]||s.chosenDJ||'rozzo');if(!DJS[chosenDJ])chosenDJ='rozzo';$('ticketSlider').value=ticketPrice;$('ticketVal').textContent='€'+ticketPrice;$('drinkSlider').value=drinkPrice;$('drinkVal').textContent='€'+drinkPrice;$('djSelect').value=chosenDJ;$('djInfo').textContent=DJS[chosenDJ].desc;log('Сохранённый клуб загружен.');tools();updateProgress();updateUI()}}catch(e){}function frame(now){if(last)simulate(Math.min(.05,(now-last)/1000));last=now;updateUI();requestAnimationFrame(frame)}requestAnimationFrame(frame);window.NightShift3D={get map(){return map},get people(){return people},get running(){return running},get paused(){return paused},get elapsed(){return elapsed},get selected(){return selected},observeMode,undoEdit,get lighting(){return lightingEnabled},get effects(){return particlesEnabled},place,moveObject,rotateObject,anchor,occupiedCells,get rotations(){return rotations},types:TYPES,get N(){return N},get clubName(){return clubName}};})();
