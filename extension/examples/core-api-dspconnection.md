# core-api-dspconnection

## 9
<!-- FMOD_DSPCONNECTION_TYPE -->
The connection types are constants on DspConnection and are passed to Dsp.addInput. PREALLOCATED is internal and not exposed.
```haxe
import haxefmod.core.Dsp;
import haxefmod.core.DspConnection;
import haxefmod.core.DspType;

var reverb = Dsp.create(DspType.SFXREVERB);
var source = Dsp.create(DspType.OSCILLATOR);
var send = reverb.addInput(source, DspConnection.TYPE_SEND);
send.setMix(0.3);
if (send.getType() == DspConnection.TYPE_SEND) {
    trace("send routing in place");
}
```
