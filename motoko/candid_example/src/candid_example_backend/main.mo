actor {
 var v : Int = 0;
 public func add(d : Nat) : async () { v += d; };
 public func subtract(d : Nat) : async () { v -= d; };
 public query func get() : async Int { v };
}
