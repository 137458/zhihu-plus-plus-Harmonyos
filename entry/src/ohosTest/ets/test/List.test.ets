import abilityTest from './Ability.test';
import zseSignerTest from './ZseSigner.test';
import networkClientTest from './NetworkClient.test';
import contentDetailTest from './ContentDetail.test';

export default function testsuite() {
  abilityTest();
  zseSignerTest();
  networkClientTest();
  contentDetailTest();
}
