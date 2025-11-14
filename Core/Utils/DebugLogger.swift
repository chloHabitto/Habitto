import Foundation

#if DEBUG
@inline(__always)
func debugLog(
  _ items: Any...,
  separator: String = " ",
  terminator: String = "\n"
) {
  let output = items.map { "\($0)" }.joined(separator: separator)
  Swift.print(output, terminator: terminator)
}
#else
@inline(__always)
func debugLog(
  _ items: Any...,
  separator: String = " ",
  terminator: String = "\n"
) {}
#endif

