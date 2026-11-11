import json,os,unittest,urllib.request,urllib.error
BASE=os.environ.get('SITE_URL','http://127.0.0.1:18080')
def get(path):
 try:r=urllib.request.urlopen(BASE+path,timeout=15)
 except urllib.error.HTTPError as e:r=e
 with r:return r.status,r.read().decode()
class Contracts(unittest.TestCase):
 def test_my_profile(self):
  status,body=get('/my/api/profile.jsp')
  self.assertEqual(status,200)
  self.assertEqual(json.loads(body)['profile']['id'],'C001')
 def test_retail_settings_page(self):
  status,body=get('/my/')
  self.assertEqual(status,200)
  self.assertIn('notificationConsent',body);self.assertNotIn('고객 관리',body)
