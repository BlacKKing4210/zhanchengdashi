/* Static visual previews only. No engine or account mutation. */
'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const K=require('../native_components/common.cjs');
const {ROOT,DATA,cardRect,loadFormalCards}=require('./core_data.cjs');
const G=DATA.geometry,C=K.C,OUT=__dirname;
const manifestFile=path.join(OUT,'subset-manifest.json');
const artSources=JSON.parse(fs.readFileSync(path.join(OUT,'native-art-sources.json'),'utf8'));
const formal=loadFormalCards();
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase();
const portraits={},records=[];
let approvedMouseCrop;
let heroBaselineCanvas;
let foliage;
function cropImage(img,bbox){const [x,y,r,b]=bbox,cn=K.createCanvas(r-x,b-y);cn.getContext('2d').drawImage(img,x,y,r-x,b-y,0,0,r-x,b-y);return cn;}
function featherCrop(cn){
 const ct=cn.getContext('2d');ct.save();ct.globalCompositeOperation='destination-in';
 let g=ct.createLinearGradient(0,0,cn.width,0);g.addColorStop(0,'#fff');g.addColorStop(.65,'#fff');g.addColorStop(1,'rgba(255,255,255,0)');ct.fillStyle=g;ct.fillRect(0,0,cn.width,cn.height);
 g=ct.createLinearGradient(0,0,0,cn.height);g.addColorStop(0,'rgba(255,255,255,0)');g.addColorStop(.13,'#fff');g.addColorStop(.65,'#fff');g.addColorStop(1,'rgba(255,255,255,0)');ct.fillStyle=g;ct.fillRect(0,0,cn.width,cn.height);ct.restore();return cn;
}
async function loadApprovedMouse(){
 const source=path.join(OUT,'04_deck_main.png'),wanted='F3B6A8496703FCE12754AF18BE67C2DCA4E90F6CD5359AB07E9BAE0F134E889B';
 if(sha(source)!==wanted)throw new Error('Approved mouse preview source changed');
 const box=[518,474,122,112],img=await K.loadImage(source),cn=cropImage(img,[box[0],box[1],box[0]+box[2],box[1]+box[3]]),ct=cn.getContext('2d'),pixels=ct.getImageData(0,0,cn.width,cn.height);
 let left=cn.width,top=cn.height,right=0,bottom=0;
 for(let i=0;i<pixels.data.length;i+=4){const r=pixels.data[i],g=pixels.data[i+1],b=pixels.data[i+2];if(g-r>3&&g-b>14)pixels.data[i+3]=0;if(pixels.data[i+3]>0){const p=i/4,x=p%cn.width,y=Math.floor(p/cn.width);left=Math.min(left,x);right=Math.max(right,x+1);top=Math.min(top,y);bottom=Math.max(bottom,y+1);}}
 ct.putImageData(pixels,0,0);portraits.mouse=cropImage(cn,[left,top,right,bottom]);
 approvedMouseCrop={id:'mouse',identity:'Same approved gray mouse ID; current formal name/common rarity/slogan remain authoritative.',source:source.replace(/\\/g,'/'),source_sha256:wanted,source_pixel_roi:box,alpha_visible_bbox_after_mask:[left,top,right,bottom],mask_rule:'Remove only green background pixels when G-R>3 and G-B>14; animal RGB untouched. No redraw, pose synthesis, silhouette or color edit.',fit_rule:'Uniform visible-alpha fit into current528x528portrait region',role:'Approved AI preview crop, not runtime asset or formal art replacement'};
}
async function loadHighResolutionMouse(source,wanted){
 const boundary=fs.realpathSync(path.join(K.KIT_ROOT,'illustrations'))+path.sep;
 source=fs.realpathSync(source);if(!source.toLowerCase().startsWith(boundary.toLowerCase()))throw new Error('Hero illustration is outside art-director-owned approved source folder');
 if(sha(source)!==wanted.toUpperCase())throw new Error('Hero illustration SHA mismatch');
 const img=await K.loadImage(source),cn=K.createCanvas(img.width,img.height),ct=cn.getContext('2d');ct.drawImage(img,0,0);
 const pixels=ct.getImageData(0,0,cn.width,cn.height);let left=cn.width,top=cn.height,right=0,bottom=0,transparent=0;
 for(let i=0;i<pixels.data.length;i+=4){if(pixels.data[i+3]===0)transparent++;if(pixels.data[i+3]>0){const p=i/4,x=p%cn.width,y=Math.floor(p/cn.width);left=Math.min(left,x);right=Math.max(right,x+1);top=Math.min(top,y);bottom=Math.max(bottom,y+1);}}
 if(!transparent||right<=left||bottom<=top)throw new Error('High-resolution mouse must have actual transparent background and visible art');
 const fit=Math.min(G.hero_portrait[2]/(right-left),G.hero_portrait[3]/(bottom-top));if(fit>1)throw new Error('Hero illustration would require upscaling; insufficient visible-pixel resolution');
 portraits.mouse=cropImage(cn,[left,top,right,bottom]);
 approvedMouseCrop={id:'mouse',identity:'Same approved04gray mouse identity/pose; current formal name/common rarity/slogan authoritative.',source:source.replace(/\\/g,'/'),source_sha256:wanted.toUpperCase(),source_pixels:[img.width,img.height],alpha_visible_bbox:[left,top,right,bottom],visible_to_target_scale:fit,source_kind:'ART_DIRECTOR_HIGH_RESOLUTION_TRANSPARENT_AI_ILLUSTRATION',fit_rule:'Uniform visible-alpha fit into fixed528x528portrait rect; no enlargement, silhouette/color editing or UI reflow',generated_by:'art_director built-in imagegen; no core-agent imagegen call',role:'Preview illustration only; not runtime animal asset replacement'};
 const retained=path.join(OUT,'iterations','09_gacha_new_hero_low_resolution.png'),current=path.join(OUT,'09_gacha_new_hero.png');
 const previous=fs.existsSync(retained)?retained:current;
 if(sha(previous)!=='9AF2738763F605C3336F4D5521C1A1A6F3467808FD9D9950D6B823E3DE6194FA')throw new Error('Original low-resolution09 baseline changed');
 const old=await K.loadImage(previous);heroBaselineCanvas=K.createCanvas(old.width,old.height);heroBaselineCanvas.getContext('2d').drawImage(old,0,0);
}
function verifyHeroOnlyChange(canvas){
 if(!heroBaselineCanvas)throw new Error('Missing protected09baseline');
 const a=heroBaselineCanvas.getContext('2d').getImageData(0,0,720,1280).data,b=canvas.getContext('2d').getImageData(0,0,720,1280).data;
 const [x,y,w,h]=G.hero_portrait;let differences=0;
 for(let row=0;row<1280;row++)for(let col=0;col<720;col++){if(col>=x&&col<x+w&&row>=y&&row<y+h)continue;const p=(row*720+col)*4;if(a[p]!==b[p]||a[p+1]!==b[p+1]||a[p+2]!==b[p+2]||a[p+3]!==b[p+3])differences++;}
 if(differences)throw new Error('Protected09UI/background pixels changed outside portrait: '+differences);
 const retained=path.join(OUT,'iterations','09_gacha_new_hero_low_resolution.png');
 if(!fs.existsSync(retained)){fs.mkdirSync(path.dirname(retained),{recursive:true});fs.copyFileSync(path.join(OUT,'09_gacha_new_hero.png'),retained);}
 return{method:'RGBA pixel equality outside Rect96,260,528,528 against retained prior09',outside_portrait_differences:differences,retained_old_iteration:retained.replace(/\\/g,'/'),retained_sha256:sha(retained),old_iteration_count:1};
}
function putPortrait(ctx,id,rect,factor=.78){
 const image=portraits[id];if(!image)throw new Error('Missing formal art '+id);
 const [x,y,w,h]=rect,s=Math.min(w/image.width,h/image.height)*factor;
 ctx.drawImage(image,x+(w-image.width*s)/2,y+(h-image.height*s)/2,image.width*s,image.height*s);
}
function forest(ctx,hero=false){
 ctx.fillStyle=hero?C.cream:'#658a41';ctx.fillRect(0,0,720,1280);
 // These four crops contain only trees/log/ground from the approved master,
 // never battle hexes, characters, controls or resource bars.
 if(!hero){
  ctx.drawImage(foliage,-28,65,184,204);
  ctx.save();ctx.translate(720,0);ctx.scale(-1,1);ctx.drawImage(foliage,-28,65,184,204);ctx.restore();
  ctx.drawImage(foliage,-28,1023,184,204);
  ctx.save();ctx.translate(720,0);ctx.scale(-1,1);ctx.drawImage(foliage,-28,1023,184,204);ctx.restore();
  K.panel(ctx,32,75,656,120,{fill:C.cream,line:0,radius:20});
 }
}
function gachaBase(state){
 const {canvas,ctx}=K.createPage();forest(ctx);
 K.resource(ctx,...G.currency_left,state.gold,'coin');
 K.resource(ctx,...G.currency_right,state.tickets,'ticket');
 K.header(ctx,'抽卡',...G.title,{size:46});
 K.resource(ctx,...G.gacha_tickets,state.tickets,'ticket');
 K.panel(ctx,...G.reward_panel,{fill:C.cream,stroke:C.ink,line:4,radius:20});
 K.text(ctx,'最近获得',...G.reward_heading,30,{align:'center'});
 return{canvas,ctx};
}
function finishGacha(ctx,state){
 K.button(ctx,...G.one_cta,'抽1次',{enabled:state.buttons_enabled[0],size:28});
 K.button(ctx,...G.ten_cta,'抽10次',{enabled:state.buttons_enabled[1],size:28});
 K.nav(ctx,'gacha');
 if(state.toast){K.panel(ctx,...G.toast,{fill:C.navy,line:3,radius:12});K.text(ctx,state.toast,...G.toast,23,{align:'center',color:'#fff'});}
}
function star(ctx,cx,cy,r){ctx.beginPath();for(let i=0;i<10;i++){const a=-Math.PI/2+i*Math.PI/5,rr=i%2?r*.45:r;const x=cx+Math.cos(a)*rr,y=cy+Math.sin(a)*rr;i?ctx.lineTo(x,y):ctx.moveTo(x,y);}ctx.closePath();ctx.fillStyle=C.gold;ctx.fill();ctx.strokeStyle=C.ink;ctx.lineWidth=3;ctx.stroke();}
function resultCard(ctx,id,rect){
 const card=formal[id],[x,y,w,h]=rect;
 const fill=card.rarity==='rare'?'#9fd7f1':card.rarity==='epic'?'#c7a7df':card.rarity==='legendary'?'#ffd765':'#b8d78f';
 K.panel(ctx,x,y,w,h,{fill,stroke:C.ink,line:3,radius:13});
 putPortrait(ctx,id,[x+6,y+6,w-12,h-34-18]);
 K.text(ctx,card.name,x+6,y+h-34-6,w-12,34,24,{align:'center'});
}
function record(id,canvas,detail={}){
 const out=path.join(OUT,id+'.png');K.save(canvas,out);
 records.push({id,output:out.replace(/\\/g,'/'),output_sha256:sha(out),output_pixels:[canvas.width,canvas.height],render_method:'USER_AUTHORIZED_NATIVE_CANVAS_COMPONENTS',status:'STATIC_VISUAL_SELF_CHECK_PENDING_ART_DIRECTOR',...detail});
}
function renderEmpty(){const state=DATA.states[0],{canvas,ctx}=gachaBase(state);K.text(ctx,'暂无记录',...G.empty_text,24,{align:'center',color:C.navy});finishGacha(ctx,state);record(state.id,canvas,{state,geometry:G,animal_assets:[]});}
function renderOpening(){const state=DATA.states[1],{canvas,ctx}=gachaBase(state),[x,y,w,h]=G.single_card;K.panel(ctx,x,y,w,h,{fill:'#465cb2',stroke:C.ink,line:4,radius:14});K.panel(ctx,x+10,y+10,w-20,h-20,{fill:'#666497',stroke:C.gold,line:3,radius:10});star(ctx,x+w/2,y+h/2,Math.min(w,h)*.18);finishGacha(ctx,state);record(state.id,canvas,{state,geometry:G,animal_assets:[],animation_boundary:'Single static normal result flip-card back; not proof of animation or first-ownership reveal.'});}
function renderTen(){const state=DATA.states[2],{canvas,ctx}=gachaBase(state);state.card_ids.forEach((id,i)=>resultCard(ctx,id,cardRect(i)));finishGacha(ctx,state);record(state.id,canvas,{state,geometry:G,cards:state.card_ids.map((id,i)=>({id,name:formal[id].name,rarity:formal[id].rarity,rect:cardRect(i)})),animal_assets:artSources.assets.filter(a=>state.card_ids.includes(a.id)),current_config_override:'Duck uses current formal rare-blue rarity; source fixture duck common-green is stale.'});}
function renderHero(){
 const state=DATA.states[3],card=formal[state.card_id],{canvas,ctx}=K.createPage();forest(ctx,true);
 if(card.name!==state.name||card.slogan!==state.slogan)throw new Error('Current hero identity/slogan differs from fixture');
 ctx.fillStyle='#e3eed1';ctx.beginPath();ctx.arc(360,525,326,0,Math.PI*2);ctx.fill();
 ctx.fillStyle='#cce2a5';ctx.beginPath();ctx.arc(360,525,254,0,Math.PI*2);ctx.fill();
 ctx.strokeStyle='#66993f';ctx.lineWidth=5;
 for(let i=0;i<12;i++){const a=i*Math.PI/6;ctx.beginPath();ctx.moveTo(360+Math.cos(a)*270,525+Math.sin(a)*270);ctx.lineTo(360+Math.cos(a)*302,525+Math.sin(a)*302);ctx.stroke();}
 putPortrait(ctx,state.card_id,G.hero_portrait,1);
 K.text(ctx,card.name,...G.hero_name,46,{align:'center'});
 K.panel(ctx,...G.hero_slogan,{fill:'#fffdf5',stroke:C.ink,line:3,radius:22});
 ctx.beginPath();ctx.moveTo(344,939);ctx.lineTo(359,919);ctx.lineTo(378,939);ctx.closePath();ctx.fillStyle='#fffdf5';ctx.fill();ctx.beginPath();ctx.moveTo(344,939);ctx.lineTo(359,919);ctx.lineTo(378,939);ctx.strokeStyle=C.ink;ctx.lineWidth=3;ctx.stroke();
 K.text(ctx,card.slogan,90,977,540,38,30,{align:'center'});
 K.button(ctx,...G.hero_continue,'继续',{size:34});
 const portrait_only_change=verifyHeroOnlyChange(canvas);
 record(state.id,canvas,{state,geometry:{portrait:G.hero_portrait,name:G.hero_name,slogan:G.hero_slogan,continue:G.hero_continue},formal_identity_source:artSources.assets.find(a=>a.id===state.card_id),animal_assets:[approvedMouseCrop],portrait_only_change,animation_boundary:'Static settled hero stage only; no card grant, ownership or animation claim.'});
}
async function repairHome(manifest){
 const job=manifest.jobs.find(j=>j.id==='03_home_daily_rewards');
 const input=job.generated_source;
 if(sha(input)!=='1E98B1F936AB15A1E59E4C74193AA9063CACC2940355D8B28429014B5B3DDC96')throw new Error('03 repair input differs from approved retained image');
 const old=await K.loadImage(input),edited=K.createCanvas(old.width,old.height),ec=edited.getContext('2d');ec.drawImage(old,0,0);
 // Clear only the incorrect old reward-ticket silhouette, using untouched
 // adjacent pixels from the same cream reward row. Number 2 starts after 748.
 ec.drawImage(old,730,607,10,54,663,607,67,54);
 const {canvas,ctx}=K.createPage(),scale=Math.min(720/old.width,1280/old.height),offset=(1280-old.height*scale)/2;
 ctx.drawImage(edited,0,offset,old.width*scale,old.height*scale);
 K.icon(ctx,'ticket',669.5*scale,607*scale+offset,54*scale,54*scale);
 record(job.id,canvas,{repair:{input,input_sha256:sha(input),old_pixels:[old.width,old.height],uniform_scale:scale,y_offset:offset,cleared_old_roi:[663,607,67,54],background_sample_roi:[730,607,10,54],native_icon:'ticket',new_icon_rect:[669.5*scale,607*scale+offset,54*scale,54*scale],unchanged:'All page pixels outside original reward-ticket slot undergo uniform scale only; digit 2, all modal text, pillows, backdrop and nav preserved.'}});
}
async function main(){
 const manifest=JSON.parse(fs.readFileSync(manifestFile,'utf8'));
 for(const source of manifest.source_hashes)if(sha(source.path)!==source.sha256)throw new Error('Formal source changed '+source.path);
 await K.initAssets();
 for(const source of artSources.assets){if(sha(source.path)!==source.sha256)throw new Error('Formal art changed '+source.id);portraits[source.id]=cropImage(await K.loadImage(source.path),source.alpha_visible_bbox);}
 const master=await K.loadImage(manifest.style_master);const sx=master.width/720,sy=master.height/1280;
 foliage=featherCrop(cropImage(master,[0,Math.round(82*sy),Math.round(140*sx),Math.round(237*sy)]));
 const only=process.argv[2]||'all';
 const heroArtArg=process.argv.find(a=>a.startsWith('--hero-art=')),heroShaArg=process.argv.find(a=>a.startsWith('--hero-sha='));
 if(manifest.quality_reopen&&only!=='09')throw new Error('Single-P1 repair scope locks the other8PNG; invoke only09');
 if(manifest.quality_reopen)for(const fixed of manifest.quality_reopen.other_png_baseline)if(sha(fixed.path)!==fixed.sha256)throw new Error('Other-page PNG changed from reopened-scope baseline '+fixed.path);
 const otherImageHashes=manifest.jobs.filter(j=>j.id!=='09_gacha_new_hero').map(j=>({path:j.output,sha256:sha(j.output)}));
 if(only==='all'||only==='03')await repairHome(manifest);
 if(only==='all'||only==='06')renderEmpty();
 if(only==='all'||only==='07')renderOpening();
 if(only==='all'||only==='08')renderTen();
 if(only==='all'||only==='09'){if(!heroArtArg||!heroShaArg)throw new Error('Explicit approved high-resolution --hero-art and --hero-sha required; low-resolution hero crop is retired');await loadHighResolutionMouse(heroArtArg.slice(11),heroShaArg.slice(11));renderHero();}
 for(const fixed of otherImageHashes)if(sha(fixed.path)!==fixed.sha256)throw new Error('Protected other-page PNG changed '+fixed.path);
 if(manifest.quality_reopen&&records.some(r=>r.id==='09_gacha_new_hero')){const rec=records.find(r=>r.id==='09_gacha_new_hero');manifest.quality_reopen.status='P1_REPAIR_HIGH_RES_HERO_PNG_AWAITING_ART_DIRECTOR';manifest.quality_reopen.new_output_sha256=rec.output_sha256;manifest.quality_reopen.replacement_asset=rec.animal_assets[0];rec.quality_reopen=manifest.quality_reopen;}
 const receipt={schema_version:1,date:'2026-10-12',mode:'NO_RUNTIME_STATIC_NATIVE_PREVIEW',renderer:path.join(OUT,'render_core.cjs').replace(/\\/g,'/'),renderer_sha256:sha(__filename),native_kit:{path:path.join(K.KIT_ROOT,'common.cjs'),sha256:sha(path.join(K.KIT_ROOT,'common.cjs')),icons:Object.fromEntries(Object.entries(K.iconPaths).map(([id,p])=>[id,{path:p,sha256:sha(p)}]))},formal_sources:[...manifest.source_hashes,{path:path.join(ROOT,'runtime/config/cards.json'),sha256:sha(path.join(ROOT,'runtime/config/cards.json'))}],animal_source_document:'native-art-sources.json',foliage_source:{path:manifest.style_master,sha256:sha(manifest.style_master),logical_crop:[0,82,140,155],rule:'Only clean forest pixels reused with alpha feather on free crop edges. No full-screen battle background or animal/control crop.'},outputs:records,boundary:'Generated files are effects only. Native coordinates prove composition geometry, not game/device behavior; all shown inventories and rewards are synthetic historical fixtures.'};
 const receiptFile=path.join(OUT,'native-render-receipt.json');let previous={outputs:[]};if(fs.existsSync(receiptFile))previous=JSON.parse(fs.readFileSync(receiptFile,'utf8'));receipt.outputs=[...previous.outputs.filter(o=>!records.some(n=>n.id===o.id)),...records];fs.writeFileSync(receiptFile,JSON.stringify(receipt,null,2)+'\n');
 manifest.client_date='2026-10-12';manifest.status='CORE_NATIVE_OUTPUTS_AWAITING_INDEPENDENT_QA';manifest.tool_policy={mode:'BUILTIN_IMAGEGEN_EXISTING_ART_PLUS_USER_AUTHORIZED_NATIVE_CANVAS',new_imagegen_calls:0,native_renderer:'render_core.cjs',canonical_native_kit:'../native_components/common.cjs'};
 manifest.recency_warning='Historical synthetic runtime fixture inputs are not fresh current-engine proof. 01/02/04/05 remain accepted legacy 941x1672 AI style previews without pixel-coordinate parity. Native 03/06/07/08/09 outputs are exactly720x1280; 03 uniform-scale icon repair, GACHA current-source component coordinates. No implementation, real account, ownership or device behavior claim.';
 for(const rec of records){const job=manifest.jobs.find(j=>j.id===rec.id);if(!job)throw new Error('Missing manifest job '+rec.id);Object.assign(job,rec);job.native_receipt='native-render-receipt.json';}
 fs.writeFileSync(manifestFile,JSON.stringify(manifest,null,2)+'\n');
 console.log(JSON.stringify(records.map(r=>({id:r.id,path:r.output,sha256:r.output_sha256,pixels:r.output_pixels})),null,2));
}
main().catch(e=>{console.error(e.stack);process.exit(1);});
