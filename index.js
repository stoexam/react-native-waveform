import {
	Platform,
	NativeModules,
    NativeAppEventEmitter
} from 'react-native';

//module.exports = NativeModules.WaveformViewModule;

let WaveformViewModule = NativeModules.WaveformViewModule;
export default {
	init(options){
		let opt = {
		    onStop(){},
			...options
		};
		let fnConf = {
			confirm: opt.onStop,
		};
		WaveformViewModule._init(opt);
        this.listener && this.listener.remove();
        this.listener = NativeAppEventEmitter.addListener('confirmEvent', event => {
            fnConf[event['type']](event['selectedValue'], event['selectedIndex']);
        });
	}
}
