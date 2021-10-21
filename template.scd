
(
var basepath;
var schedSequence, stopSequence, schedClock, send;
var format_number, retrieve_number;
var webmidi_sysex_id, sc_sysex_id, sysex_msgs;
var webmidi_output_id, webmidi_input_id;
var scheduled, sched_int;

basepath = '/Users/dorianvelazquez/Documents/';


webmidi_sysex_id = 111;   // webmidi will send this to match on SC side
sc_sysex_id = 112;        // SC will send this to match on web side

webmidi_input_id = -1391581464;
webmidi_output_id = -476611835;

scheduled = nil;
sched_int = 8;

send = {|fun_id,msg|
	var id;

	id = MIDIClient.destinations.collect({|x| x.uid}).indexOf(webmidi_output_id);
	if(id.isNil, {}, {
		var out,raw_msg;

		out = MIDIOut.new(id);
		raw_msg = Int8Array[0xF0];

		raw_msg = raw_msg.addAll([sc_sysex_id,fun_id]++msg);

		raw_msg = raw_msg ++ Int8Array[0xF7];
		out.sysex( raw_msg);
	})
};

retrieve_number = {|numArr|
	var sign,intPart,decPart, num;
	sign = if(numArr[0]==0, {-1}, {1});

	intPart = numArr[3..2+numArr[1]];
	decPart = numArr[numArr.size-numArr[2]..];

	num = "";
	intPart.collect({|x| num = num ++ x.asString});
	num = num++".";
	decPart.collect({|x| num = num ++ x.asString});

	num = num.asFloat * sign;
	num;
};

format_number={|num|
	var numArr, sign, intPart, decPart, numsplit;

	if((num.class.asString == "Integer") || (num.class.asString == "Float"), {
		numArr = [];

		sign = if(num>0,{1},{0});

		numsplit = (num.abs).asString.split($.);
		numsplit = if(numsplit.size == 1, { numsplit++["0"] },{ numsplit });

		intPart = numsplit[0].findRegexp(".{1,2}").collect({|x| x[1]});
		decPart = numsplit[1].findRegexp(".{1,2}").collect({|x| x[1]})[0..1];

		numArr = [sign,intPart.size,decPart.size] ++intPart ++ decPart;
		numArr = numArr.collect({|x| x.asInteger});
		numArr;
	},{[]})
};




sysex_msgs = Dictionary[
	\tick      -> Dictionary[
		\id  -> 0,
		\fun -> {
			if(scheduled.isNil,{
				var i=0;
				scheduled = 1;
				p.clock.sched(1/sched_int,{
					send.value(sysex_msgs[\tick][\id],[i]);
					i = (i+1)%sched_int;
					1/sched_int
				});
			}, {});
		}
	],  // tick clock to WebMidi on 1/32 of SC tempoclock
	\ping -> Dictionary[
		\id  -> 1,
		\fun -> {
			"ping from webmidi".postln;
			send.value(sysex_msgs[\ping][\id],[]);
		}
	],
	\loadSamples -> Dictionary[
		\id -> 2,
		\fun -> {
			s.waitForBoot({
				"loading buffer samples".postln;
				// sample buffers
				b = ['andrea.wav', 'rexma.wav','yuri.wav'].collect({|name, i|
					Buffer.read(s, basepath++name, action:{|buf|
						var frames;
						frames = format_number.value(buf.numFrames);
						["frames",frames].postln;

						send.value(sysex_msgs[\loadSamples][\id],[i]++frames);
					})
				});

				p[\out].play;
				p[\out] = {Pan2.ar(p[\seq].ar,0)};
				// ndefs storage

				n = Dictionary();
				//schedClock.value;
			})
		}
	],
	\schedSeq -> Dictionary[
		\id  -> 3,
		\fun -> {|seq_id, attr ...value|
			var numChannels,bufnum,rate,tempo,start,amp;
			[\incomin_data,seq_id, attr, value].postln;
			if( n[seq_id].isNil , {
				n[seq_id] = Dictionary[
					\sample_id -> 0,
					\start -> 0,
					\rate -> 1,
					\tempo -> 1,
					\amp -> 1,
					\numChannels -> b[0].numChannels
				];
			}, { n[seq_id]});

			switch(attr,
				0, {
					// sample_id
					n[seq_id][\sample_id] = value[0];
					n[seq_id][\numChannels] = b[value[0]].numChannels;
				},
				1, {
					// start
					value = retrieve_number.value(value);
					[\start,value].postln;
					n[seq_id][\start] = value;
				},
				2, {
					// rate
					value = retrieve_number.value(value);
					n[seq_id][\rate] = value;
				},
				3, {
					// tempo
					value = retrieve_number.value(value);
					n[seq_id][\tempo] = value;

				},
				4, {
					// amp
					value = retrieve_number.value(value);
					n[seq_id][\amp] = value;

				}
			);


			numChannels =  n[seq_id][\numChannels];
			bufnum = n[seq_id][\sample_id];
			rate = n[seq_id][\rate];
			tempo  = n[seq_id][\tempo];
			start =  if(n[seq_id][\start] == -0.0,{0},{n[seq_id][\start]});
			amp =  n[seq_id][\amp];

			[seq_id,numChannels,bufnum,rate,tempo,start,amp,\aaaaaaaaaa].postln;
			p[\seq][seq_id].release;
			p[\seq][seq_id] = {
				var sig;
				sig = PlayBuf.ar(
					numChannels,
					bufnum,
					BufRateScale.kr(bufnum)*rate,
					Impulse.ar(~tempo.ar*1*tempo),
					start
				) ;

				sig = Pan2.ar((sig.tanh)) * amp;
				sig;

			};


		}
	],  // create a sequence NDef
];




// start proxy space + tempo clock
p = ProxySpace.push(s.boot);
s.waitForBoot({p.makeTempoClock});

// start with midi
MIDIClient.init;
MIDIIn.connectAll;



schedClock = {
	var i=0;
	p.clock.sched(1/32,{
		MIDIOut(0).sysex(Int8Array[0xF0, sc_sysex_id , sysex_msgs[\tick][\id], i , 0xF7]);
		i = (i+1)%32;
		1/32
	});
};

/*

schedSequence = {|id, sample_id, start=0, rate=1, tempo=1,amp=1|
	var nname, numChannels;
	nname = \seq ++ id ++ \x;

	numChannels = b[sample_id].numChannels;

	n[id] = if( n[id].isNil , {
		[\miau,\miau].postln;
		Ndef(nname, {  |bufnum, rate = 1, start, tempo,amp=1|
			var sig;
			[\numchannels,numChannels.value].postln;

			sig = PlayBuf.ar(
				numChannels.value,
				bufnum,
				BufRateScale.kr(bufnum)*rate,
				Impulse.ar(~tempo.ar*tempo),
				start,
				1
			);

			sig = (sig.tanh) * amp;
			sig;
		})
	}, { n[id] });
	n[id].quant(1);
	n[id].set(
		\bufnum,b[sample_id].bufnum,
		\rate, rate,
		\tempo,tempo,
		\start, start,
		\amp,amp
	);
	n[id].play;
};
*/

stopSequence = {|id|
	n[id] = if( n[id].isNil, {}, n[id]);
	n[id].stop;
	n[id].release;
	n.put(id,nil)
};



MIDIFunc.sysex({|data,src|
	var fun, fun_id;
	if(data[1] == webmidi_sysex_id && src == webmidi_input_id, {
		fun_id = sysex_msgs.values.collect({|x| x[\id]}).indexOf(data[2]);
		fun = if( fun_id.isNil, {{}},{
			var args;
			data = data.asList;

			args = if(data.size>4, {data[3..data.size-2]}, {[]});
			fun = sysex_msgs[sysex_msgs.keys.asArray[fun_id]][\fun];

			fun.valueArray(args)
		});
	});
});

)

n[0].set(\start,25397)
n[1].play

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



































n[0][\amp

]


s.plotTree





































































































n = Dictionary[]

n[10] = 666

n[0]

l = n[0]
l = 555



(
p = ProxySpace.push(s.boot);

p.makeTempoClock;
)

b = ['andrea.wav', 'rexma.wav','yuri.wav'].collect({|name, i|
	Buffer.read(s,'/Users/dorianvelazquez/Documents/'++name)
});

p[\salida].play
p[\salida] = {Pan2.ar(p[\seq].ar,0)}
(
var numChannels;
var bufnum, rate, start, tempo,amp;
var seq_id = 2;
numChannels = b[seq_id].numChannels;
bufnum =  b[seq_id].bufnum;
rate = 0.1;
tempo = 2;
start = -0.0;
amp = 1;
p[\seq][1] = {
	var sig;
	sig = PlayBuf.ar(
		numChannels,
		bufnum,
		BufRateScale.kr(bufnum)*rate,
		Impulse.ar(~tempo.ar*tempo),
		start,

	);

	sig = Pan2.ar((sig.tanh) * amp);
	sig;
};
)
s.plotTree



p[\out].play
p[\out] =  { Pan2.ar(Limiter.ar(p[\in].ar,0.6),0)};

p[\in]
p[\in][0] = {|freq=200| Pan2.ar(SinOsc.ar(freq).tanh/2)}
p[\in][1] = {|freq=300| Pan2.ar(SinOsc.ar(freq).tanh/2)}

p[\in][1].set(\freq,900)

















List[ 0, 2, 1, 1, 1, 0, 2, -9 ]
f=List[ -16, 111, 3, -9 ]

f[3..2]
if(f.size>4, {f[3..f.size-2]}, {[]})









p[\seq0x].set(\amp,1)













n[0].set(\start,2000)










s.plotTree
















s.plotTree



















l = NodeProxy(s)

l.source = {|freq=500| SinOsc.ar(freq)}
l.play

l.set(\freq, 200)


p[0].play
p[0] =













p[ 'seq'+0].play

p[ 'seq'+0] = {|freq=100| SinOsc.ar(freq)}
p[ 'seq'+0] = {SinOsc.ar(800)}
p['seq'+0].set(\freq,300)
p





p = ProxySpace.push(s.boot)

p[\a] = {SinOsc.ar()}
p[\a].play






s.plotTree






n

(

{|a,b... c|
	[a,b,c].postln;
}.valueArray(Int8Array[1,2,3].asList)
)
















b = ['andrea.wav', 'rexma.wav','yuri.wav'].collect({|name, i|
	Buffer.read(s,'/Users/dorianvelazquez/Documents/'++name)
})

p.quant(1)


(
n=Dictionary[];
c = {|id, sample_id, start=0, rate=1, tempo=1,amp=1|
	var nname, numChannels;
	nname = \seq ++ id ++ \x;

	numChannels = b[sample_id].numChannels;

	n[id] = if( n[id].isNil , {
		[\miau,\miau].postln;
		Ndef(nname, {  |bufnum, rate = 1, start, tempo,amp=1|
			var sig;
			[\numchannels,numChannels.value].postln;

			sig = PlayBuf.ar(
				numChannels.value,
				bufnum,
				BufRateScale.kr(bufnum)*rate,
				Impulse.ar(~tempo.ar*tempo),
				start,
				1
			);

			sig = (sig.tanh) * amp;
			sig;
		})
	}, { n[id] });

	n[id].set(
		\bufnum,b[sample_id].bufnum,
		\rate, rate,
		\tempo,tempo,
		\start, start,
		\amp,amp
	);
	n[id].quant(1);
	n[id].play;
};
)
//c.value(0,0,b[0].numFrames/8,-0.2,1)

2.value



c.value(0,0,b[0].numFrames/8,0.15,1,4)





b[2].numFrames


([1,2,]++[3]).collect({|x| x.class})

l=Int8Array[]
l.addAll([0xF0])

l.class
(Int8Array[0xF0]++[2])


MIDIOut(0).sysex(Int8Array[0xF0, 22 , 11, 2 , 0xF7]);
retrieve_number

({|numArr|



})

({|num|
	var numArr, sign, intPart, decPart, numsplit;

	if((num.class.asString == "Integer") || (num.class.asString == "Float"), {
		numArr = [];

		sign = if(num>0,{1},{0});

		numsplit = (num.abs).asString.split($.);
		numsplit = if(numsplit.size == 1, { numsplit++["0"] },{ numsplit });

		numsplit.postln;
		intPart = numsplit[0].findRegexp(".{1,2}").collect({|x| x[1]});
		decPart = numsplit[1].findRegexp(".{1,2}").collect({|x| x[1]})[0..1];

		numArr = [sign,intPart.size,decPart.size] ++intPart ++ decPart;
		numArr.collect({|x| x.asInteger});
		numArr;
	},{[]})
}.value(22.56948)
)




"foobar".findAllRegexp("o*bar");

"10.34".findRegexp(".{1,2}");

(10.9).class

true || false

"hola.hola".split($.)[0]

10.class.asString == "Integer"

(
{|numArr|
	var sign,intPart,decPart, num;
	sign = if(numArr[0]==0, {-1}, {1});

	intPart = numArr[3..2+numArr[1]];
	decPart = numArr[numArr.size-numArr[2]..];

	num = "";
	intPart.collect({|x| num = num ++ x.asString});
	num = num++".";
	decPart.collect({|x| num = num ++ x.asString});

	num = num.asFloat * sign;
	num;

}.value([ 1, 1, 2, 22, 56, 94 ])
)


",".join([ "23", "44" ])




[0, 1, 2, 23, 39, 67].asString


b[0].numFrames

(
var frames,buf;
frames=[];
buf = b[0];
0.forBy(buf.numFrames.asString.size,2,{|x|
	var dig;
	dig = buf.numFrames.asString[x..x+1];
	if(dig == "",{},  {frames = frames.add( buf.numFrames.asString[x..x+1].asInteger )})
});
frames.postln;
)

f
z

0.forBy(f.asString.size,2,{|x|
	f.asString[x..x+1].asInteger.postln
})

0.forBy()

b[1].numFrames


f**(1/4)

4.loop({|x| x})
(b[0].numFrames) 0

b[0].numFrames**(1/7)
i=

i=2
(b[0].numFrames.asString)[0..i]


[5].asM




MIDIOut(0).sysex(Int8Array([ -16, 112, 1, 247 ]))


In8Array()

[6,5,4,3].collect({|x,i| [x,i].postln})

MIDIOut(0).sysex([0xF0, 111 ,2,127,4,0xF7]);

b[0].numFrames

(
var val;
val={|nframes|
	var frames;
	frames = Array.fill(nframes/127, 127) ++ [nframes%127];
	frames
}.value((127*4 ) +200);
val.postln;
val.sum.postln;
)

[ 127, 127, 46 ].sum

Array.fill(2/127, 127)


(0.1).asInt

Array.fill(20,3)

127%127
(128-127)>>7

f =[]
f = f.add(1)






		e.sysex(Int8Array[0xF0, 22 , 0,1, 0xF7]);


e=MIDIClient.destinations[MIDIClient.destinations.collect({|x| x.uid}).indexOf(-476611835)];

l=MIDIOut.connectByUID(-476611835)
l.sysex(Int8Array[0xF0, 22 , 0,1, 0xF7]);




MIDIIn(0).sysex

MIDIClient.sources[0]


MIDIClient.destinations[0].asMIDIInPortUID

MIDIOut(2,-1391581464).sysex()

b.collect({|x| x.path}).collect({|x| x=="/Users/dorianvelazquez/Documents/anrea.wav"}).indexOf(true)


k
k=b[0]

l=Buffer.read(s, '/Users/dorianvelazquez/Documents/'++'rexma.wav',action:{|buffer| buffer.numFrames.postln})

l.action_
k.waitF
m = Int8Array([1,2,3])


{
	[6].postln;
}.valueArray([6,6,6])

(9..0)[2..]




m = Dictionary[
	\tick      -> Dictionary[
		\id  -> 0,
		\fun -> {}
	],  // tick clock to WebMidi on 1/32 of SC tempoclock
	\createSeq -> Dictionary[
		\id  -> 1,
		\fun ->  {|id, sample_id, start=0, rate=1, tempo=1|
			var nname;
			rate = [0,rate,127].normalize(-127/2,127/2)[1];
			rate.postln;
			nname = \seq ++ id ++ \x;
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
				\numChannels, b[sample_id].numChannels,
				\bufnum,b[sample_id].bufnum,
				\rate, rate,
				\tempo,tempo,
				\start, (start/127) * b[sample_id].numFrames
			);
			n[id].play;
		}
	],  // create a sequence NDef
];


m.keys


l=MIDIIn(0)

d=MIDIClient.destinations[0].uid

d.


		MIDIOut(0,-1391581464).sysex(Int8Array[0xF0, 22 , 0,1, 0xF7]);




-1391581464



MIDIIn.



Int8Array[0xF0, 112] ++ Int8Array[0, 1]
Int8Array([0xF0, 112,0, 1 , 0xF7])




i = 0;
i = i+1;
i%32


/*
~a = ({|id|
	var sample;
	sample = b[id];
	{
		PlayBuf.ar(sample.numChannels, sample.bufnum, BufRateScale.ir(sample.bufnum), Impulse.ar(~tempo.ar))
	}
}.value(1))

m.set("hola")
(
~a.play;
~a = {|sample_id=(-1)|
	var sample;
	sample = b[0];
	PlayBuf.ar(sample.numChannels, sample.bufnum, BufRateScale.ir(sample.bufnum), Impulse.ar(~tempo.ar))
})
b.at(0)

~a.set(\sample,b[1])


b[0] == nil

w=[0,1,2,3]

w.indexOf(5)

[1, 2, 1, 2].collect(_.isNil).indexOf(true).isNil == false;

~a*/
/*
(
var createSequence;

createSequence = {|id, sample, start=0, tempo=1, rate=1|
	var f;

	f=if([id, sample, start, tempo, rate].collect(_.isNil).indexOf(true).isNil, {{}}, {
		var samp;
		samp = b[0];
		{//PlayBuf.ar(samp.numChannels, samp.bufnum,BufRateScale.kr(samp.bufnum) , Impulse.ar(~tempo.ar*tempo),start)
			PlayBuf.ar(samp.numChannels, samp.bufnum,BufRateScale.kr(samp.bufnum) , Impulse.ar(~tempo.ar*tempo),start)
		};
	});

	/*f = if(b[sample] == nil, {},{
		PlayBuf.ar(b[sample].numChannels, b[sample].bufnum,BufRateScale.ir(b[sample].bufnum) * rate, Impulse.ar(~tempo.ar*tempo),start)
	});*/
};

q.free;
q = MIDIFunc.sysex({|data|
	data.postln;
	Ndef(\holi,{switch(data[2],
		1,createSequence.value(data[3], data[4], data[5],data[6], data[7]))}
);
})
)

*/



(
var createSequence, stopSequence,schedClock;


schedClock = {
	p.clock.sched(1/64,{
		"holaaaaa".postln;
		schedClock()
	});
};


createSequence = {|id, sample_id, start=0, rate=1, tempo=1|
	var nname;
	rate = [0,rate,127].normalize(-127/2,127/2)[1];
	rate.postln;
	nname = \seq ++ id ++ \x;
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
		\numChannels, b[sample_id].numChannels,
		\bufnum,b[sample_id].bufnum,
		\rate, rate,
		\tempo,tempo,
		\start, (start/127) * b[sample_id].numFrames
	);
	n[id].play;
};

stopSequence = {|id|
	n[id] = if( n[id].isNil, {}, n[id]);
	n[id].stop;
	n[id].release;
	n.put(1,nil)
};

createSequence.value(1,0,50,64.5,10);
)


{
	p.clock.sched(1/64,{
		"holaaaaa".postln;
		1/64
	});
};


p.clock.sche



n[1].clear

	a=	Ndef({})

	(1).asString

	Ndef(\sample++0++\a).release;


q.

	Ndef(\holi).set(\bn,0 );
(
l = Dictionary[
	0 -> Dictionary[
		// sysex id 1 id sample start tempo rate
		\sample  -> 0, //
		\start   -> 0, //
		\tempo   -> 1, //
		\rate    -> 1, //
		\channel -> 0, // chan
		\amp     -> 0, // Velocity
	],
]
)
l[0]

m=Int8Array[]
m.addAll([3,2])
.fill(1)

MIDIFunc.trace(true)


s.plotTree
MIDIClient.getClientID