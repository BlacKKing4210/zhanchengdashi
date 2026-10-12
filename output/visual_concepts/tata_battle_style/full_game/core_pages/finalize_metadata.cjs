'use strict';
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const D=__dirname,sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase();
const manifestPath=path.join(D,'subset-manifest.json'),m=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
const receipt=JSON.parse(fs.readFileSync(path.join(D,'native-render-receipt.json'),'utf8'));
if(process.argv.includes('--reopen-hero')){
 const job=m.jobs.find(j=>j.id==='09_gacha_new_hero'),baseline='9AF2738763F605C3336F4D5521C1A1A6F3467808FD9D9950D6B823E3DE6194FA';
 if(sha(job.output)!==baseline)throw new Error('09 reopen baseline changed');
 m.quality_reopen={finding_id:'CORE-HERO-HIGH-RES-09',status:'P1_OPEN_ASSET_PENDING',producer:'root',reviewer:'lead_art_director',reason:'The122x112 approved card crop is visibly pixelated as a528portrait; MINOR acceptance was reopened asP1 by producer and art-director agreement.',previous_output_sha256:baseline,scope:'Only09hero illustration and corresponding own metadata; preserve all UI/layout/state values and other8PNG',required_asset_owner:'art_director',preserve_single_low_resolution_iteration:true,guard:'RGBA differences outside96,260,528,528 must equal0',other_png_baseline:m.jobs.filter(j=>j.id!==job.id).map(j=>({path:j.output,sha256:sha(j.output)}))};
 m.status='CORE_NINE_PREVIEW_P1_REOPENED_SINGLE_HERO_ART_UPDATE';m.pending_review=[job.id];job.status='P1_HERO_ILLUSTRATION_REPLACEMENT_PENDING_ASSET';job.quality_reopen=m.quality_reopen;
 if(job.independent_review){job.previous_independent_review=job.independent_review;delete job.independent_review;}
 const rec=receipt.outputs.find(r=>r.id===job.id);rec.status=job.status;rec.quality_reopen=m.quality_reopen;if(rec.independent_review){rec.previous_independent_review=rec.independent_review;delete rec.independent_review;}
 fs.writeFileSync(manifestPath,JSON.stringify(m,null,2)+'\n');fs.writeFileSync(path.join(D,'native-render-receipt.json'),JSON.stringify(receipt,null,2)+'\n');
 console.log(JSON.stringify({status:m.status,baseline,protected_other_png:m.quality_reopen.other_png_baseline.length,pending_asset_owner:'art_director'},null,2));process.exit(0);
}
const instructions={
 '03_home_daily_rewards':'Native exact icon repair only. Load the retained generated-source image, remove only incorrect reward ticket in original ROI663,607,67,54 using adjacent untouched same-row cream pixels730,607,10,54. Replace with canonical blue paw ticket, uniformly fitted, preserving count2. Uniform contain-scale the full legacy941x1672 page to720x1280. All other pixels/data/geometry unchanged.',
 '06_gacha_empty':'Native720x1280 static empty fixture:60coin,0bluepawticket in both source slots; current title抽卡/最近获得/暂无记录; source blank rewardpanel; both draw actions disabled gray; standard five nav active抽卡. No art/results/toast/account data. Exact current source rectangles in native-scene-data.json.',
 '07_gacha_opening':'Native720x1280 static normal flip-card fixture:60coin,29bluepawticket top and center. Single current normal cardback228,460,264,316:bluepurple border/yellow inner frame/fivepoint star. Both CTAs disabled. Toast获得1张卡牌 at CURRENT generic toast130,1018,460,58. Standard five nav active抽卡. This is not the distinct new-hero paw-card reveal.',
 '08_gacha_ten_result':'Native720x1280 static result:60coin,20ticket top and center. Current source132x158 cards,gaps40x28,rows2/3/3/2 with row2 x-12,row3 x+12. Exact IDsfrog,ant,sparrow,rabbit,duck,snail,hamster,pigeon,parrot,rabbit; current formal names/rarities;duck andparrot blue,othersgreen. Formal original art_pathPNG uniformly visible-alpha fitted at0.78. Only names, no added stats/levels. Both CTAs enabled, toast获得10张卡牌 source130,1018,460,58. Standard five nav active抽卡.',
 '09_gacha_new_hero':'Native720x1280 static settled new-mouse hero:formal identity老鼠 and current CSV common rarity/slogan; reuse approved04_deck_main gray mouse animal pixel crop518,474,122,112, transparently remove green background only; portrait96,260,528,528 uniformly visible-alpha fit; commongreen two radialcircles and12rays; exact name64,840,592,64; slogan bubble64,936,592,128,exact鼠鼠我呀，主打一个人多。 at fontsize30; ONLY继续138,1112,444,76. No currency/nav/stats/level/title/rarity instructions. No card grant/ownership/animation claim.'
};
const heroOutput=receipt.outputs.find(r=>r.id==='09_gacha_new_hero');
if(heroOutput&&heroOutput.animal_assets&&heroOutput.animal_assets[0].source_kind==='ART_DIRECTOR_HIGH_RESOLUTION_TRANSPARENT_AI_ILLUSTRATION')instructions['09_gacha_new_hero']='Native720x1280 static settled mouse hero:current formal identity/name/common rarity/slogan. Use art-director approved high-resolution transparent illustration '+heroOutput.animal_assets[0].source+' SHA'+heroOutput.animal_assets[0].source_sha256+'. Uniform alpha-visible fit into unchanged portrait96,260,528,528, never upscale. Keep exact old09circles/rays,name64,840,592,64,slogan bubble64,936,592,128,exact鼠鼠我呀，主打一个人多。 fontsize30,ONLY继续138,1112,444,76. Pixel equality outside portrait required against sole retained low-resolution09iteration. No currency/nav/stats/level/new features or runtime grant.';
for(const r of receipt.outputs){
 const j=m.jobs.find(j=>j.id===r.id);if(!j)throw new Error('Unknown native job '+r.id);
 if(j.output_sha256!==sha(j.output)||r.output_sha256!==sha(j.output))throw new Error('Output changed '+r.id);
 if(!j.historical_imagegen_planning_prompt)j.historical_imagegen_planning_prompt=j.prompt;
 j.prompt=instructions[r.id];j.prompt_file='prompts/'+r.id+'.native-instruction.txt';
 const instructionPath=path.join(D,j.prompt_file),instructionText=j.prompt+'\n';if(!fs.existsSync(instructionPath)||fs.readFileSync(instructionPath,'utf8')!==instructionText)fs.writeFileSync(instructionPath,instructionText,'utf8');
 j.native_receipt='native-render-receipt.json';j.source_kind=j.id==='06_gacha_empty'?'CURRENT_SOURCE_STATE_DERIVED_FROM_HISTORICAL_SYNTHETIC_FIXTURE':j.id==='03_home_daily_rewards'?'ACCEPTED_AI_PREVIEW_WITH_NATIVE_ICON_REPAIR':'HISTORICAL_SYNTHETIC_FIXTURE_WITH_CURRENT_SOURCE_GEOMETRY_AND_CONFIG';
 j.portrait_source_kind=j.id==='09_gacha_new_hero'?(r.animal_assets[0].source_kind||'APPROVED_EXISTING_AI_PREVIEW_GRAY_MOUSE_PIXEL_CROP'):j.id==='08_gacha_ten_result'?'CURRENT_FORMAL_PROJECT_ART_PATH_PNG':'NONE';
 j.self_check={status:'STATIC_PNG_VISUALLY_INSPECTED',target_pixels:[720,1280],text_width_guard:'@napi-rs/canvas measureText; overflow throws, no font shrinking/ellipsis',current_sources_unchanged:true,no_runtime_claim:true};
}
const fixed={
 '01_home_selected':'0A1AA4678A950D190CB3D96FE5E53BBDA132333E29D627E8EB32061A59EC8EC0',
 '02_home_new_tomorrow':'A519F1D6320BB62573016BBD780000AFDA9DE719DBE6813AE1E02B2D84D3C9BB',
 '04_deck_main':'F3B6A8496703FCE12754AF18BE67C2DCA4E90F6CD5359AB07E9BAE0F134E889B',
 '05_deck_upgrade':'3ECFFCD6F88757763CCAA245D4BE5EF18FC86EEAFF95254A1BE1071893BD6648'
};
for(const [id,wanted] of Object.entries(fixed)){
 const j=m.jobs.find(j=>j.id===id);if(sha(j.output)!==wanted)throw new Error('Accepted page changed '+id);
 j.resolution_class='ACCEPTED_LEGACY_941x1672_UNCHANGED';j.protection_check='SHA256_UNCHANGED_FROM_ART_DIRECTOR_PASS';
}
for(const j of m.jobs){j.design_canvas=[720,1280];j.raster_size=j.output_pixels;j.coordinate_evidence=j.id.startsWith('06_')||j.id.startsWith('07_')||j.id.startsWith('08_')||j.id.startsWith('09_')?'Current-source fixed component rectangles rendered natively; no engine/device behavior proof':j.id==='03_home_daily_rewards'?'Legacy AI preview uniformly scaled with one native icon replacement; full-page exact source-coordinate parity not claimed':'Unchanged accepted AI legacy preview; relative layout inspected, source-pixel exactness not established';}
for(const s of m.source_hashes)if(sha(s.path)!==s.sha256)throw new Error('Formal source changed '+s.path);
m.native_completion={renderer:'render_core.cjs',renderer_sha256:sha(path.join(D,'render_core.cjs')),geometry:'native-scene-data.json',formal_art_mapping:'native-art-sources.json',receipt:'native-render-receipt.json',instructions:'prompts/*.native-instruction.txt',reproduction:'Bundled Node executable -> render_core.cjs 09 --hero-art=<approved native_components/illustrations/PNG> --hero-sha=<SHA256>. Requires referenced project originals/master and sole retained old09iteration. Reopened single-hero scope locks other8PNG; no download or new core-agent imagegen.',toolkit_read_only:true,new_imagegen_calls:0,legacy_pages_protected:Object.keys(fixed),all_nine_png_present:m.jobs.every(j=>fs.existsSync(j.output)),write_boundary:'Only full_game/core_pages/**; no runtime/config/source writes.'};
const reviewPath=path.join(D,'../reviews/core_pages.json');
if(fs.existsSync(reviewPath)){
 const review=JSON.parse(fs.readFileSync(reviewPath,'utf8'));let missing=[];
 for(const j of m.jobs){
  const entry=review.files.find(f=>f.path==='core_pages/'+j.id+'.png'&&f.sha256===sha(j.output));
  const reopenedOld=m.quality_reopen&&j.id==='09_gacha_new_hero'&&sha(j.output)===m.quality_reopen.previous_output_sha256;
  if(entry&&!reopenedOld&&entry.p0.length===0&&entry.p1.length===0&&entry.verdict.startsWith('PREVIEW_PASS')){j.status='PREVIEW_ART_DIRECTOR_PASS';j.independent_review={path:'../reviews/core_pages.json',sha256:sha(reviewPath),verdict:entry.verdict,output_sha256:entry.sha256};const r=receipt.outputs.find(r=>r.id===j.id);if(r){r.status=j.status;r.independent_review=j.independent_review;}}
  else missing.push(j.id);
 }
 m.status=missing.length?'CORE_NINE_COMPLETE_PNGS_INDEPENDENT_REVIEW_PENDING':'CORE_NINE_PREVIEW_PASS_NO_RUNTIME';m.pending_review=missing;
 if(m.quality_reopen){m.quality_reopen.status=missing.includes('09_gacha_new_hero')?'P1_OPEN_HIGH_RES_HERO_REPAIR_REVIEW_PENDING':'P1_CLOSED_HIGH_RES_HERO_ART_DIRECTOR_PASS';m.jobs.find(j=>j.id==='09_gacha_new_hero').quality_reopen=m.quality_reopen;receipt.outputs.find(r=>r.id==='09_gacha_new_hero').quality_reopen=m.quality_reopen;}
}
if(m.pending_review&&m.pending_review.length===0){
 const removed=[];for(const rel of ['work/mouse-crop-study.png','inspect_mouse_crop.cjs']){
  const target=path.resolve(D,rel),boundary=path.resolve(D)+path.sep;
  if(!target.toLowerCase().startsWith(boundary.toLowerCase()))throw new Error('Cleanup outside owned output');
  if(fs.existsSync(target)){const st=fs.lstatSync(target);if(!st.isFile()||st.isSymbolicLink())throw new Error('Unexpected temporary file type');removed.push({path:target,bytes:st.size});fs.unlinkSync(target);}
 }
 const work=path.resolve(D,'work');if(fs.existsSync(work)&&!fs.lstatSync(work).isSymbolicLink()&&fs.readdirSync(work).length===0)fs.rmdirSync(work);
 if(removed.length)m.cleanup={status:'BOUNDED_OWN_TEMPORARY_CROP_STUDY_REMOVED',removed,logical_deleted_bytes:removed.reduce((n,r)=>n+r.bytes,0),disk_space_delta:'Not independently measured',retained:'All nine finalPNG, reproducible renderer/instructions/receipts, original04source and all formal project art/source/user edits preserved.'};
}
fs.writeFileSync(manifestPath,JSON.stringify(m,null,2)+'\n');
fs.writeFileSync(path.join(D,'native-render-receipt.json'),JSON.stringify(receipt,null,2)+'\n');
console.log(JSON.stringify({status:m.status,pending_review:m.pending_review,all_nine_png_present:m.native_completion.all_nine_png_present,preserved_legacy_sha:true,formal_source_sha:true,native_output_sha:true},null,2));
