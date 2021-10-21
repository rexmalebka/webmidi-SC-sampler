export default function(config:any){
	const samples = config.samples.map( (x:any)=> `Buffer.read(s,basepath++'${x.name}')`).join(', ')

	return `
(
var basepath;
var createSequence, stopSequence, schedClock;
var webmidi_sysex_id, sc_sysex_id, sysex_msgs;

basepath = '${config.basepath}';


webmidi_sysex_id = ${config.webmidi_sysex_id};   // webmidi will send this to match on SC side
sc_sysex_id = ${config.sc_sysex_id};        // SC will send this to match on web side

sysex_msgs = Dictionary[
	\\tick      -> Dictionary[
		\\id  -> ${config.sysex_msgs.tick.id},
		\\fun -> {}
	],  // tick clock to WebMidi on 1/32 of SC tempoclock
	\\loadSamples -> Dictionary[
		\\id  -> ${config.sysex_msgs.loadSamples.id},
		\\fun -> {
			s.waitForBoot({
				// sample buffers
				b = [${samples}];

				// ndefs storage
				n = Dictionary();
				schedClock.value;
			})
		}
	]
];




// start proxy space + tempo clock
p = ProxySpace.push(s.boot);
p.makeTempoClock;
// start with midi



MIDIClient.init;
MIDIIn.connectAll;



schedClock = {
	var i=0;
	p.clock.sched(1/32,{
		MIDIOut(0).sysex(Int8Array[0xF0, sc_sysex_id , sysex_msgs[\\tick][\\id], i , 0xF7]);
		i = (i+1)%32;
		1/32
	});
};

createSequence = {|id, sample_id, start=0, rate=1, tempo=1|
	var nname;
	rate = [0,rate,127].normalize(-127/2,127/2)[1];
	rate.postln;
	nname = \\seq ++ id ++ \\x;
	n[id] = if( n[id].isNil, {
		Ndef(nname, {  |bufnum, rate = 1, start, tempo|
			var sig;
			sig = PlayBuf.ar(
				2,
				bufnum,
				BufRateScale.kr(bufnum)*rate,
				Impulse.ar(~tempo.ar*tempo),
				start,
				1
			);
			sig;
		})
	}, { n[id] });
	n[id].set(
		\\numChannels, b[sample_id].numChannels,
		\\bufnum,b[sample_id].bufnum,
		\\rate, rate,
		\\tempo,tempo,
		\\start, (start/127) * b[sample_id].numFrames
	);
	n[id].play;
};

stopSequence = {|id|
	n[id] = if( n[id].isNil, {}, n[id]);
	n[id].stop;
	n[id].release;
	n.put(1,nil)
};




MIDIFunc.sysex({|data|
	var fun, fun_id;
	if(data[1] == webmidi_sysex_id, {
		fun_id = sysex_msgs.values.collect({|x| x[\\id]}).indexOf(data[2]);
		fun = if( fun_id.isNil, {{}},{
			fun = sysex_msgs[sysex_msgs.keys.asArray[fun_id]][\\fun];
			fun.valueArray(data.asArray[3..])
		});
	});
});

)



	`
}
