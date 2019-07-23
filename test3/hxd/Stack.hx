package hxd;


private class StackIterator<T> {
	var b : Array<T>;
	var len : Int;
	var pos : Int;
	public inline function new( b : Array<T>,len:Int )  {
		this.b = b;
		this.len = len;
		this.pos = 0;
	}
	public inline function hasNext() {
		return pos < len;
	}
	public inline function next() {
		return b[pos++];
	}
}

private class BackwardStackIterator<T> {
	var b : Array<T>;
	var len : Int;
	var pos : Int;
	public inline function new( b : Array<T>,len:Int )  {
		this.b = b;
		this.len = len;
		this.pos = 0;
	}
	public inline function hasNext() {
		return pos < len;
	}
	public inline function next() {
		return b[len - pos++ - 1];
	}
}

//could be an abstract but they are not reliable enough at the time I write this 
@:generic
class Stack<T>  {
	var arr : Array<T>=[];
	var pos = 0;
	
	public var length(get, never):Int; inline function get_length() return pos;
	public var quota(get, never):Int; inline function get_quota() return arr.length;
	
	public inline function new() {}
	
	/**
	 * slow, breaks order but no realloc nor mass move
	 */
	public inline function remove(v:T):Bool{
		var i = arr.indexOf(v);
		return removeAt(i);
	}
	
	public inline function random():T{
		return arr[Std.random( get_length() )];
	}
	
	public inline function removeOrdered(v:T):Bool {
		if ( pos == 0 ) return false;
		var i = arr.indexOf(v);
		if ( i < 0 ) return false;
		
		return 
		if ( i >= pos ) {
			arr[i] = null;
			false;
		} else 
			removeOrderedAt(i);
	}
	
	public inline function removeOrderedAt(idx:Int):Bool {
		if ( idx < 0 ) return false;
		if ( pos == 0 ) return false;
		for ( i in idx...pos)
			arr[i] = arr[i + 1];
		pos--;
		return true;
	}
	
	public inline function removeAt(i:Int):Bool {
		if ( i < 0 ) return false;
		if( pos > 1 ){
			arr[i] = arr[pos-1];
			arr[pos-1] = null;
			pos--;
		}
		else {
			arr[0] = null;
			pos = 0;
		}
		return true;
	}
	
	public function reverse<T>() {
		for ( i in 0...length>>1) {
			var t = arr[i];
			arr[i] = arr[length - 1 - i];
			arr[length - 1 - i] = t;
		}
	}
	
	@:noDebug
	public inline function reserve(n) {
		if (arr.length < n )
			arr[n] = null;
		return this;
	}
	
	public inline function push(v:T) {
		arr[pos++] = v;
	}
	
	public inline function pop() : T {
		if ( pos == 0 ) return null;
			
		var v = arr[pos-1]; 
		arr[--pos] = null;
		return v;
	}
	
	public inline function first() : T {
		if ( pos == 0 ) return null;
		return arr[0];
	}
	
	public function pushFront(v:T){
		for ( i in 0...pos )
			arr[pos - i] = arr[pos - i - 1];
		arr[0] = v;
		pos++;
	}
	
	public function swap(i0,i1) {
		if ( i0 == i1) return;
		var t = arr[i0];
		arr[i0] = arr[i1];
		arr[i1] = t;
	}
	
	public inline function last() : T {
		if ( pos == 0 ) return null;
		return arr[pos - 1];
	}
	
	public inline function indexOf(elem:T) : Int { 
		return arr.indexOf(elem);
	}
	
	public inline function unsafeGet(idx:Int) {
		return arr[idx];
	}
	
	public inline function hardReset() {
		for ( i in 0...arr.length) arr[i] = null;
		pos = 0;
	}
	
	public inline function reset() {
		pos = 0;
	}
	
	public inline function iterator() return new StackIterator(arr,get_length());
	public inline function backWardIterator() return new BackwardStackIterator(arr,get_length());	
	public inline function toString() {
		var s = "";
		for ( i in 0...pos) {
			s += Std.string(arr[i]);
		}
		return s;
	}
	
	public inline function toData() 	return arr;
	public inline function toArray() 	return arr;
	
	public inline function fill(arr:Array<T>) {
		for ( a in arr )
			push( a );
		return this;
	}
	
	public inline function get(pos:Int) {
	  return arr[pos];
	}
	
	public inline function set(pos:Int, v:T):T {
		arr[pos] = v;
		return v;
	}
	
	public function has( v:T ){
		var idx = arr.indexOf(v);
		return idx >= 0 && idx < pos;
	}
	
	public function scramble() {
		var rd = Std.random;
		for(x in 0...(length + rd( length )) ){
			var b = rd(length);
			var a = rd(length);
			var temp = arr[a];
			arr[ a ] = arr[ b ];
			arr[ b ] = temp;
		}
	}
}

class StackTest {
	public static function test() {
		var a : hxd.Stack<Null<Int>> = new hxd.Stack<Null<Int>>(); 
		a.fill([1, 2, 3, 4]);
		a.removeOrdered(3);
		if ( a.get(0) != 1 || a.get(2) != 4) throw "assert";
		trace(a);
		
		var a : hxd.Stack<Null<Int>> = new hxd.Stack<Null<Int>>() 
		.fill([1, 2, 3, 4]);
		
		a.pushFront( 0 ); 
		if ( a.get(0) != 0 || a.get(2) != 2) throw "assert";
		
		var a : hxd.Stack<Null<Int>> = new hxd.Stack<Null<Int>>();
		a.pushFront( 66 ); 
		trace(a);
	}
}