(async()=>{const B='1137440518329425584',S='/spirit0447/halo-raves/',P={},sl=t=>new Promise(r=>setTimeout(r,t));
const csrf=(document.cookie.match(/csrftoken=([^;]+)/)||[])[1];
const R=async(n,o)=>{const u=`/resource/${n}/get/?source_url=${encodeURIComponent(S)}&data=${encodeURIComponent(JSON.stringify({options:o,context:{}}))}`;
const r=await fetch(u,{headers:{'Accept':'application/json','X-Requested-With':'XMLHttpRequest','X-Pinterest-AppState':'active',...(csrf?{'X-CSRFToken':csrf}:{})}});
if(!r.ok)throw n+' '+r.status;return (await r.json()).resource_response;};
const pg=async(n,o)=>{let b,a=[];do{const r=await R(n,b?{...o,bookmarks:[b]}:o);a.push(...(r.data||[]));b=r.bookmark;console.log(n,a.length);await sl(400)}while(b&&b!=='-end-');return a};
const im=p=>{const i=p.images||{};for(const k of['orig','1200x','736x','474x','236x'])if(i[k]&&i[k].url)return i[k].url};
const add=(p,s)=>{if(!p||!p.id||(p.type&&p.type!=='pin'))return;if(P[p.id]){if(s&&!P[p.id].section)P[p.id].section=s;return}
P[p.id]={id:String(p.id),created_at:p.created_at||null,title:p.title||p.grid_title||null,description:p.description||null,link:p.link||null,image_url:im(p)||null,section:s||null}};
try{for(const z of[250,100,25]){(await pg('BoardFeedResource',{board_id:B,board_url:S,page_size:z,field_set_key:'react_grid_pin',layout:'default'})).forEach(p=>add(p));console.log('feed',z,'total',Object.keys(P).length);if(Object.keys(P).length>=290)break}
for(const s of await pg('BoardSectionsResource',{board_id:B,page_size:25}))(await pg('BoardSectionPinsResource',{section_id:s.id,page_size:250})).forEach(p=>add(p,s.title))}
catch(e){console.warn('API failed, scrolling page instead:',e);let last=-1,same=0;while(same<6){document.querySelectorAll('a[href*="/pin/"]').forEach(a=>{const id=(a.href.match(/\/pin\/(\d+)/)||[])[1],g=a.querySelector('img');
if(id&&!P[id])P[id]={id,created_at:null,title:null,description:g&&g.alt||null,link:null,image_url:g?g.src.replace(/\/\d+x\//,'/originals/'):null,section:null}});
const n=Object.keys(P).length;same=n===last?same+1:0;last=n;console.log('scraped',n);scrollBy(0,innerHeight*2);await sl(1500)}}
const L=Object.values(P);console.log('%cDONE: '+L.length+' pins. Saving halo-pins.json','font-size:18px;color:#c6ff00');
const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(L,null,1)],{type:'application/json'}));a.download='halo-pins.json';document.body.appendChild(a);a.click();})();
