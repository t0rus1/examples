import Text "mo:base/Text";
import Bool "mo:base/Bool";

actor characterCount {

  public func test(text: Text) : async Bool {
    let size = Text.size(text);
    return size % 2 == 0;
  };
};