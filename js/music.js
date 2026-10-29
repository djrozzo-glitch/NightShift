(()=>{'use strict';
const frame=document.getElementById('soundcloudPlayer'),status=document.getElementById('musicStatus'),vol=document.getElementById('musicVolume'),mute=document.getElementById('musicMute'),select=document.getElementById('djSelect'),track=document.getElementById('musicTrack');
const TRACKS={
 vanya:{title:'vanya velin — BCCO Premiere',url:'https://soundcloud.com/bcco/bcco-premiere-vanya-velin'},
 velvet37:{title:'velvet 37 — My Angel',url:'https://soundcloud.com/velvet-37/my-angel-1'},
 rozzo:{title:'rozzo — Velocity',url:'https://soundcloud.com/seethesearecords/velocity'},
 lutanina:{title:'lutanina — Two RNDM 06 02',url:'https://soundcloud.com/user-880945103/two-rndm-06-02'},
 neonexus:{title:'neonexus — Backdoor Radio Mix',url:'https://soundcloud.com/amn303/backdoor-radio-mix-neonexus'},
 lowq:{title:'lowQ — Waves of Light',url:'https://soundcloud.com/shiftedrecordings/waves-of-light-1'},
 zlostniy:{title:'zlostniy — Shine (ft. zlostniy)',url:'https://soundcloud.com/velvet-37/shine-ft-zlostniy'},
 raison:{title:'Raison — Even Sexier Groove',url:'https://soundcloud.com/raison_d_etre/even-sexier-groove'}
};
let widget=null,ready=false,playingWanted=false,pausedWanted=false,muted=false,volume=55,currentDJ=null,loadToken=0;
const message=t=>{status.textContent=t};
const playButton=document.getElementById('musicPlay');
const trackLink=document.getElementById('musicExternal');
function updateTrackLink(){const url=TRACKS[currentDJ]?.url;trackLink.href=url||'https://soundcloud.com';trackLink.textContent=url?'↗ Открыть трек в SoundCloud':'↗ SoundCloud'}
playButton.addEventListener('click',()=>{playingWanted=true;pausedWanted=false;if(widget&&ready){widget.play();message('Запуск музыки… Если плеер не отвечает, открой трек в SoundCloud.')}else message('Плеер ещё загружается. Можно открыть трек в SoundCloud.')});
function setVolume(){if(widget&&ready)widget.setVolume(muted?0:volume);mute.textContent=muted?'🔇 ВЫКЛ':'🔊 ЗВУК'}
function sync(){if(!ready||!widget)return;const t=TRACKS[currentDJ];if(!t){widget.pause();message('Трек SoundCloud недоступен');return}if(!playingWanted){widget.pause();message('Музыка запустится при открытии клуба');return}if(pausedWanted){widget.pause();message('Музыка на паузе');return}widget.play();message('Запускаем · '+t.title+' · Если нет звука, нажми ▶ или открой трек по ссылке')}
function selectTrack(force=false){const dj=select.value,t=TRACKS[dj];if(dj===currentDJ&&!force)return;currentDJ=dj;track.textContent=t?t.title:'Выбери диджея';updateTrackLink();const token=++loadToken;if(!widget||!ready)return;if(!t){widget.pause();message('Трек SoundCloud недоступен');return}widget.pause();message('Загрузка · '+t.title);widget.load(t.url,{auto_play:false,show_artwork:false,visual:false,show_comments:false,hide_related:true,show_reposts:false,show_teaser:false,color:'#c55ce3',callback:()=>{if(token!==loadToken)return;setVolume();sync()}})}
vol.addEventListener('input',()=>{volume=Number(vol.value);if(volume>0)muted=false;setVolume()});
mute.addEventListener('click',()=>{muted=!muted;setVolume()});
select.addEventListener('change',selectTrack);
window.addEventListener('nightshift:started',()=>{
 playingWanted=true;pausedWanted=false;
 // A direct user gesture is required by Chrome for embedded SoundCloud playback.
 // Play the existing widget first; load the selected track only if it changed.
 if(widget&&ready){if(currentDJ!==select.value)selectTrack(true);else sync()}
 else selectTrack(true);
});
window.addEventListener('nightshift:pause',e=>{pausedWanted=!!e.detail.paused;sync()});
window.addEventListener('nightshift:ended',()=>{playingWanted=false;pausedWanted=false;sync()});
updateTrackLink();
if(!window.SC||!window.SC.Widget){message('SoundCloud API не загрузился — проверь блокировщик или обнови страницу');return}
widget=window.SC.Widget(frame);
widget.bind(window.SC.Widget.Events.READY,()=>{ready=true;setVolume();selectTrack(true)});
widget.bind(window.SC.Widget.Events.ERROR,()=>{message('SoundCloud не воспроизводит этот трек во встроенном плеере. Открой его по ссылке ниже.');console.warn('NightShift SoundCloud widget error',currentDJ)});
widget.bind(window.SC.Widget.Events.PLAY,()=>{if(playingWanted&&!pausedWanted)message('♫ Играет · '+(TRACKS[currentDJ]?.title||'SoundCloud'))});
widget.bind(window.SC.Widget.Events.PLAY_PROGRESS,()=>{if(playingWanted&&!pausedWanted)message('♫ Играет · '+(TRACKS[currentDJ]?.title||'SoundCloud'))});
widget.bind(window.SC.Widget.Events.FINISH,()=>{if(playingWanted&&!pausedWanted&&TRACKS[currentDJ]){widget.seekTo(0);widget.play()}});
})();
