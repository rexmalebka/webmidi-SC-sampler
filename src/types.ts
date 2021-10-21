interface sample{
	name: string
	frames: number
}

export interface sequence{
	index: number
	sample: sample
	position: Function
	rate: Function
	tempo: Function
	amp: Function
}
