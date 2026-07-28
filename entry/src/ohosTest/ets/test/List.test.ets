import abilityTest from './Ability.test';
import zseSignerTest from './ZseSigner.test';
import networkClientTest from './NetworkClient.test';

export default function testsuite() {
  abilityTest();
  zseSignerTest();
  networkClientTest();
}
