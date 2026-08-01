import abilityTest from './Ability.test';
import zseSignerTest from './ZseSigner.test';
import networkClientTest from './NetworkClient.test';
import contentDetailTest from './ContentDetail.test';
import cookieJarTest from './CookieJar.test';
import zhihuSessionTest from './ZhihuSession.test';
import assetStoreTest from './AssetStore.test';
import authApiTest from './AuthApi.test';
import urlHostUtilTest from './UrlHostUtil.test';

export default function testsuite() {
  abilityTest();
  zseSignerTest();
  networkClientTest();
  contentDetailTest();
  cookieJarTest();
  zhihuSessionTest();
  assetStoreTest();
  authApiTest();
  urlHostUtilTest();
}
