const fs=require('node:fs'),test=require('node:test'),assert=require('node:assert/strict');
const ts=require(process.env.HARMONYX_TYPESCRIPT || 'D:/DevEco Studio/tools/ohpm/node_modules/typescript/lib/typescript.js');
function compile(source,globals){const result={};const code=ts.transpileModule(source,{compilerOptions:{target:ts.ScriptTarget.ES2020,module:ts.ModuleKind.CommonJS}}).outputText;new Function('exports',...Object.keys(globals),code)(result,...Object.values(globals));return result;}
test('upgrading resets an alternate launcher icon without blocking startup', async () => {
  const names = [];
  let supported = true;
  let rejects = false;
  const { restoreDefaultAppIcon } = compile(fs.readFileSync('entry/src/main/ets/services/AppIconStore.ets', 'utf8'), {
    require: name => name === '@kit.AbilityKit'
      ? { bundleManager: { setAlternateIcon: async icon => { names.push(icon); if (rejects) throw Error(); } } }
      : { deviceInfo: { apiAvailable: () => supported } }
  });
  await restoreDefaultAppIcon();
  rejects = true;
  await restoreDefaultAppIcon();
  supported = false;
  await restoreDefaultAppIcon();
  assert.deepEqual(names, ['', '']);
});
function profileMethods(){
  const file=fs.readFileSync('entry/src/main/ets/pages/UserDetail.ets','utf8').replace('export struct UserDetail','class UserDetail');
  const tree=ts.createSourceFile('profile.ts',file,ts.ScriptTarget.Latest,true);
  const node=tree.statements.find(n=>ts.isClassDeclaration(n)&&n.name?.text==='UserDetail');
  const names=['activityTabs','loadProfilePage'];
  return names.map(name=>node.members.find(n=>n.name?.getText(tree)===name).getText(tree)).join('\n');
}
test('likes appear only on the viewers own profile and use the paged likes endpoint',async()=>{
  const calls=[];
  const {Harness}=compile('export class Harness {\n'+profileMethods()+'\n}',{
    xPrivateClient:{sessionGeneration:()=>1,userLikes:async(id,cursor,count)=>{calls.push([id,cursor,count]);return {ok:true,body:''};}},
    XTimelineParser:{parse:()=>({tweets:[{id:'like'}],nextToken:'next'})},authStore:{isSignedIn:()=>false},
    ProfileTweetPage:{merge:(_tab,previous,next,replace)=>replace?next:[...previous,...next]}});
  const profile=Object.assign(new Harness(),{isSelfProfile:true,activityTabOrder:[0,1,3,2,4],privateProfileAvailable:true,
    resolvedUserId:()=>'viewer',alive:true,notifyActivityChanged(){},activityPages:Array.from({length:7},()=>({loading:false,loaded:false,posts:[],cursor:'',status:''}))});
  assert.deepEqual(profile.activityTabs(),[0,1,3,2,4,6]);
  await profile.loadProfilePage(6,true);
  assert.deepEqual(calls,[['viewer','',20]]);assert.deepEqual(profile.activityPages[6].posts,[{id:'like'}]);
  await profile.loadProfilePage(6,false);assert.deepEqual(calls[1],['viewer','next',20]);
  profile.isSelfProfile=false;
  assert.deepEqual(profile.activityTabs(),[0,1,3,2,4]);
  await profile.loadProfilePage(6,true);assert.equal(calls.length,2);
});
