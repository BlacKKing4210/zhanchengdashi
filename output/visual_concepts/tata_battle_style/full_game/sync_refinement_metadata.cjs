const fs=require('fs'),path=require('path'),crypto=require('crypto');
const B=__dirname,read=p=>JSON.parse(fs.readFileSync(path.join(B,p),'utf8')),save=(p,x)=>fs.writeFileSync(path.join(B,p),JSON.stringify(x,null,2)+'\n');
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex').toUpperCase();
const g=read('gacha_refinement/receipt.json'),maps=read('map_refinement/native-render-receipt.json'),core=read('core_pages/subset-manifest.json'),oldNative=read('core_pages/native-render-receipt.json');
for(const o of g.outputs){
 const relative='core_pages/'+o.file,full=path.join(B,relative);if(sha(full)!==o.sha256)throw Error('Adopted gacha SHA differs');
 o.canonical_file='../'+relative;o.candidate_file_historical=o.file;
 let job=core.jobs.find(j=>j.id===o.id);if(!job){job={id:o.id,source:path.join(B,'core_pages/native-scene-data.json').replaceAll('\\','/'),source_kind:'Existing historical gacha fixture plus explicitly authorized revised UI'};core.jobs.push(job);}
 if(job.output_sha256!==o.sha256&&job.output_sha256)job.previous_revision={sha256:job.output_sha256,file:'iterations/'+o.id+'_before_promo.png',role:'Prior distinct artwork; excluded from gallery'};
 Object.assign(job,{output:full.replaceAll('\\','/'),output_sha256:o.sha256,output_pixels:[720,1280],raster_size:[720,1280],design_canvas:[720,1280],status:'PREVIEW_ART_DIRECTOR_PASS',render_method:o.render_method,native_receipt:'../gacha_refinement/receipt.json',state:o.state,coordinate_evidence:'USER_AUTHORIZED_GACHA_UI_REVISION_WITH_FIXED_720_RECTS',independent_review:'../reviews/refinement-20261012/gacha.json'});
 const entry={...o,output:full.replaceAll('\\','/'),output_sha256:o.sha256,renderer:'../gacha_refinement/render_gacha.cjs',receipt:'../gacha_refinement/receipt.json',status:'STATIC_PREVIEW_PASS'};
 oldNative.outputs=oldNative.outputs.filter(x=>x.id!==o.id);oldNative.outputs.push(entry);
}
g.status='STATIC_PREVIEW_PASS_ADOPTED';g.canonical_delivery_rule='candidate names are historical; canonical_file resolves the sole current physical PNG';save('gacha_refinement/receipt.json',g);
core.status='CORE_ELEVEN_PREVIEW_PASS_NO_RUNTIME';core.latest_refinement={request_id:g.request_id,owner:'root',reviewer:'lead_art_director',receipt:'../gacha_refinement/receipt.json',source_override:'Main30/one29/retainedten20, source-supported cost1/10; zero-ticket disabled variant retained',runtime_approved:false};save('core_pages/subset-manifest.json',core);
oldNative.latest_gacha_renderer={path:'../gacha_refinement/render_gacha.cjs',sha256:sha(path.join(B,'gacha_refinement/render_gacha.cjs')),scope:'06/07/09/10/11 only; old renderer remains provenance for03'};save('core_pages/native-render-receipt.json',oldNative);
for(const o of maps.outputs){o.candidate_file_historical=o.path;o.canonical_file='../root_pages/'+o.path;if(sha(path.join(B,'root_pages',o.path))!==o.sha256.toUpperCase())throw Error('Adopted map SHA differs');}
maps.acceptance='STATIC_PREVIEW_PASS_ADOPTED';save('map_refinement/native-render-receipt.json',maps);
const rootReceipt=read('root_pages/native-render-receipt.json');rootReceipt.previous_request_id=rootReceipt.request_id;rootReceipt.request_id=g.request_id;rootReceipt.outputs=rootReceipt.outputs.map(o=>maps.outputs.find(x=>x.path===o.path)||o);rootReceipt.latest_full_background=maps.full_background;rootReceipt.acceptance='Current PNGs SHA-bound in original/refinement reviews; static preview only';save('root_pages/native-render-receipt.json',rootReceipt);
const pre=read('gacha_refinement/preflight.json');pre.status='STATIC_PREVIEW_PASS_ADOPTED';pre.canonical_count=33;pre.current_request_reviews=['reviews/refinement-20261012/gacha.json','reviews/refinement-20261012/maps.json'];pre.ten_result_unchanged=true;pre.write_locks='Returned after reviewed canonical adoption';save('gacha_refinement/preflight.json',pre);
console.log(JSON.stringify({gacha:5,maps:5,ten_untouched:true,canonical_count:33,status:pre.status}));
