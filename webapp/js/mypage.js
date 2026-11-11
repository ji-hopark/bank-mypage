import {api,$,message} from '/site/site.js';
let busy=false;
$('preferences-form').addEventListener('submit',async e=>{e.preventDefault();if(busy)return;busy=true;e.submitter.disabled=true;try{await api('/my/api/preferences.jsp',{notificationConsent:$('notificationConsent').checked});message('preferences-message','알림 설정을 저장했어요.');}catch(e){message('preferences-message',e.message,true);}finally{busy=false;e.submitter.disabled=false;}});
