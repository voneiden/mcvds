import atdf
import gleam/io

pub fn main() {
  io.println("Hello from mcvds!")
  io.debug(atdf.parse_atdf("./tmp/ATtiny814.atdf"))
}
