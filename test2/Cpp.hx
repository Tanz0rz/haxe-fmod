
typedef Ptr<T> = cpp.Pointer<T>;

class Cpp {

	@:extern
	public static inline function addr<T>( a : T ){
		return cpp.Pointer.addressOf(a);
	}
	
	@:extern
	public static inline function nullptr<T>(){
		return cast null;
	}
	
}