(() => {
'use strict';
const $ = id => document.getElementById(id);
const svg = $('pitch');
const NS = 'http://www.w3.org/2000/svg';
const formations = {
 '4-3-3': [[['LW','9'],['ST','10'],['RW','7']],[['CM','8'],['CM','6'],['CM','11']],[['LB','3'],['CB','4'],['CB','5'],['RB','2']]],
 '4-4-2': [[['ST','9'],['ST','10']],[['LM','11'],['CM','8'],['CM','6'],['RM','7']],[['LB','3'],['CB','4'],['CB','5'],['RB','2']]],
 '4-2-3-1': [[['ST','9']],[['LW','11'],['CAM','10'],['RW','7']],[['CDM','8'],['CDM','6']],[['LB','3'],['CB','4'],['CB','5'],['RB','2']]],
 '3-5-2': [[['ST','9'],['ST','10']],[['LM','11'],['CM','8'],['CDM','6'],['CM','7'],['RM','2']],[['CB','3'],['CB','4'],['CB','5']]],
 '3-4-3': [[['LW','11'],['ST','9'],['RW','10']],[['LM','8'],['CM','6'],['CM','7'],['RM','2']],[['CB','3'],['CB','4'],['CB','5']]],
 '5-3-2': [[['ST','9'],['ST','10']],[['CM','8'],['CM','6'],['CM','7']],[['LWB','11'],['CB','3'],['CB','4'],['CB','5'],['RWB','2']]]
};
function lineup(formation) {
 const rows = formations[formation];
 return [...rows.flatMap((row,r) => row.map(([role,number],i) => ({name:role,role,number,x:80+(i+1)*520/(row.length+1),y:175+r*(525/(rows.length-1))}))),{name:'GK',role:'GK',number:'1',x:340,y:815}];
}
function defaults(){return {title:'나의 베스트 일레븐',formation:'4-3-3',color:'#c8f36a',opponents:false,names:true,players:lineup('4-3-3'),arrows:[]};}
let state=defaults(), selected=-1, tool='move', gesture=null;
try { const saved=JSON.parse(localStorage.getItem('squadboard-v1')); if(saved && formations[saved.formation] && /^#[0-9a-f]{6}$/i.test(saved.color) && typeof saved.title==='string' && Array.isArray(saved.players) && saved.players.length===11 && saved.players.every(p=>Number.isFinite(p.x)&&Number.isFinite(p.y)&&typeof p.name==='string'&&typeof p.role==='string') && Array.isArray(saved.arrows)) state={...state,...saved}; } catch {}
function save(){try{localStorage.setItem('squadboard-v1',JSON.stringify(state));$('save-status').textContent='● 이 기기에 자동 저장';}catch{$('save-status').textContent='저장 공간을 사용할 수 없습니다';}}
function el(tag,attrs={},text){const n=document.createElementNS(NS,tag);Object.entries(attrs).forEach(([k,v])=>n.setAttribute(k,v));if(text!==undefined)n.textContent=text;return n;}
function field(){
 svg.replaceChildren();svg.append(el('rect',{width:680,height:920,fill:'#254d36'}));
 for(let y=0;y<920;y+=92)svg.append(el('rect',{x:0,y,width:680,height:46,fill:'#2c573e'}));
 const lines=el('g',{fill:'none',stroke:'#c3d7c0','stroke-opacity':'.65','stroke-width':2});
 for(const a of [{x:24,y:24,width:632,height:872},{x:184,y:24,width:312,height:140},{x:258,y:24,width:164,height:55},{x:184,y:756,width:312,height:140},{x:258,y:841,width:164,height:55}])lines.append(el('rect',a));
 lines.append(el('path',{d:'M24 460H656 M304 24V9H376V24 M304 896V911H376V896 M274 164 A79 79 0 0 0 406 164 M274 756 A79 79 0 0 1 406 756'}));
 lines.append(el('circle',{cx:340,cy:460,r:79}));svg.append(lines);
 for(const y of [126,460,794])svg.append(el('circle',{cx:340,cy:y,r:3,fill:'#c3d7c0'}));
 const defs=el('defs');const marker=el('marker',{id:'arrowhead',viewBox:'0 0 10 10',refX:9,refY:5,markerWidth:6,markerHeight:6,orient:'auto-start-reverse'});marker.append(el('path',{d:'M0 0L10 5L0 10Z',fill:'#ffe5a0'}));defs.append(marker);svg.append(defs);
}
function arrow(a,preview=false){return el('path',{d:`M${a.x1} ${a.y1}L${a.x2} ${a.y2}`,fill:'none',stroke:'#ffe5a0','stroke-width':4,'stroke-linecap':'round','stroke-dasharray':preview?'9 6':'none','marker-end':'url(#arrowhead)','pointer-events':'none'});}
function token(p,i,opponent=false){const g=el('g',{transform:`translate(${p.x} ${p.y})`,class:opponent?'opponent':'player',...(opponent?{}:{'data-player':i,tabindex:0,role:'button','aria-label':`${p.name}, ${p.number}번. 선택 후 방향키로 이동`})});
 if(!opponent&&selected===i)g.append(el('circle',{r:31,fill:'none',stroke:'#f1ffd6','stroke-width':2,'stroke-dasharray':'4 4'}));
 g.append(el('circle',{cy:3,r:25,fill:'#0a1a15','fill-opacity':'.3'}));g.append(el('circle',{r:24,fill:opponent?'#ec826a':p.role==='GK'?'#f4cc76':state.color,stroke:'#f3ffe2','stroke-opacity':'.6','stroke-width':1.5}));g.append(el('text',{'text-anchor':'middle',y:6,fill:'#15241b','font-size':18,'font-weight':800,'font-family':'sans-serif'},p.number));
 if(state.names){const label=el('text',{'text-anchor':'middle',y:45,fill:'#fff','font-size':13,'font-family':'sans-serif',stroke:'#173021','stroke-width':4,'paint-order':'stroke', 'stroke-linejoin':'round'},p.name);g.append(label);}return g;
}
function renderPitch(){field();state.arrows.forEach(a=>svg.append(arrow(a)));if(state.opponents)lineup(state.formation).forEach((p,i)=>svg.append(token({...p,x:680-p.x,y:920-p.y},i,true)));state.players.forEach((p,i)=>svg.append(token(p,i)));}
function renderRoster(){const list=$('roster');list.replaceChildren();state.players.forEach((p,i)=>{const b=document.createElement('button');b.className='roster-player'+(selected===i?' selected':'');for(const [c,t] of [['roster-number',p.number],['roster-name',p.name],['roster-role',p.role]]){const s=document.createElement('span');s.className=c;s.textContent=t;b.append(s);}b.onclick=()=>select(i);list.append(b);});}
function select(i){selected=i;$('editor').hidden=false;$('player-name').value=state.players[i].name;$('player-number').value=state.players[i].number;$('player-role').value=state.players[i].role;renderPitch();renderRoster();}
function render(){ $('team-name').value=state.title;$('board-title').textContent=state.title||'나의 스쿼드';$('formation').value=state.formation;$('formation-badge').textContent=state.formation;$('team-color').value=state.color;$('opponents').checked=state.opponents;$('names').checked=state.names;renderPitch();renderRoster();}
function point(e){const pt=new DOMPoint(e.clientX,e.clientY).matrixTransform(svg.getScreenCTM().inverse());return {x:Math.max(28,Math.min(652,pt.x)),y:Math.max(30,Math.min(870,pt.y))};}
svg.addEventListener('pointerdown',e=>{if(e.button!==0)return;const pos=point(e);if(tool==='arrow'){gesture={type:'arrow',start:pos,last:pos};}else{const g=e.target.closest('[data-player]');if(!g)return;const i=Number(g.dataset.player);select(i);gesture={type:'player',i,dx:state.players[i].x-pos.x,dy:state.players[i].y-pos.y};}svg.setPointerCapture(e.pointerId);e.preventDefault();});
svg.addEventListener('pointermove',e=>{if(!gesture)return;const pos=point(e);if(gesture.type==='player'){const p=state.players[gesture.i];p.x=Math.max(35,Math.min(645,pos.x+gesture.dx));p.y=Math.max(40,Math.min(860,pos.y+gesture.dy));renderPitch();}else{gesture.last=pos;renderPitch();svg.append(arrow({x1:gesture.start.x,y1:gesture.start.y,x2:pos.x,y2:pos.y},true));}});
function end(cancel=false){if(!gesture)return;if(gesture.type==='arrow'&&!cancel){const {start,last}=gesture;if(Math.hypot(start.x-last.x,start.y-last.y)>15)state.arrows.push({x1:start.x,y1:start.y,x2:last.x,y2:last.y});}gesture=null;renderPitch();save();}
svg.addEventListener('pointerup',()=>end());svg.addEventListener('pointercancel',()=>end(true));
svg.addEventListener('keydown',e=>{const g=e.target.closest('[data-player]');if(!g)return;const i=Number(g.dataset.player);if(e.key==='Enter'||e.key===' '){e.preventDefault();select(i);$('player-name').focus();}const d={ArrowLeft:[-5,0],ArrowRight:[5,0],ArrowUp:[0,-5],ArrowDown:[0,5]}[e.key];if(d){e.preventDefault();const p=state.players[i];p.x=Math.max(35,Math.min(645,p.x+d[0]));p.y=Math.max(40,Math.min(860,p.y+d[1]));renderPitch();svg.querySelector(`[data-player="${i}"]`).focus();save();}});
$('team-name').oninput=e=>{state.title=e.target.value;$('board-title').textContent=state.title||'나의 스쿼드';save();};
$('formation').onchange=e=>{const fresh=lineup(e.target.value);state.players=fresh.map((p,i)=>({...state.players[i],x:p.x,y:p.y,role:p.role}));state.formation=e.target.value;selected=-1;$('editor').hidden=true;render();save();};
$('team-color').oninput=e=>{state.color=e.target.value;renderPitch();save();};
for(const key of ['opponents','names'])$(key).onchange=e=>{state[key]=e.target.checked;renderPitch();save();};
for(const [id,key] of [['player-name','name'],['player-number','number'],['player-role','role']])$(id).oninput=e=>{if(selected<0)return;if(key==='number'&&(!Number.isInteger(+e.target.value)||+e.target.value<1||+e.target.value>99))return;state.players[selected][key]=e.target.value;renderPitch();renderRoster();save();};
document.querySelectorAll('[data-tool]').forEach(b=>b.onclick=()=>{tool=b.dataset.tool;document.querySelectorAll('[data-tool]').forEach(n=>n.classList.toggle('active',n===b));svg.style.cursor=tool==='arrow'?'crosshair':'';});
$('undo').onclick=()=>{state.arrows.pop();renderPitch();save();};
$('reset').onclick=()=>{if(!confirm('선수 이름과 배치를 포함한 보드를 초기화할까요?'))return;state=defaults();selected=-1;$('editor').hidden=true;render();save();};
$('export').onclick=async()=>{
 const button=$('export');button.disabled=true;button.textContent='이미지 만드는 중…';
 try{const clone=svg.cloneNode(true);clone.setAttribute('xmlns',NS);clone.querySelectorAll('[tabindex]').forEach(n=>{n.removeAttribute('tabindex');n.removeAttribute('class');});const source=new Blob([new XMLSerializer().serializeToString(clone)],{type:'image/svg+xml;charset=utf-8'});const url=URL.createObjectURL(source);try{const image=new Image();image.src=url;await image.decode();const canvas=document.createElement('canvas');canvas.width=1360;canvas.height=2010;const ctx=canvas.getContext('2d');ctx.fillStyle='#191f1b';ctx.fillRect(0,0,1360,2010);ctx.fillStyle='#f0f4ef';ctx.font='bold 44px sans-serif';ctx.fillText(state.title||'나의 스쿼드',48,75,1260);ctx.fillStyle=state.color;ctx.font='24px sans-serif';ctx.fillText(`SQUADBOARD  /  ${state.formation}`,48,126);ctx.drawImage(image,0,170,1360,1840);const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/png'));if(!blob)throw Error('export');const download=URL.createObjectURL(blob);const a=document.createElement('a');a.href=download;a.download='squadboard.png';a.click();setTimeout(()=>URL.revokeObjectURL(download),1000);}finally{URL.revokeObjectURL(url);}}catch{$('save-status').textContent='이미지 저장에 실패했습니다. 다시 시도해 주세요.';}finally{button.disabled=false;button.textContent='↓ 이미지 저장';}
};
render();
})();
