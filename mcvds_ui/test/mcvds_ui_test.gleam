import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
import mcvds_types
import mcvds_ui

pub fn main() {
  gleeunit.main()
}

pub fn set_pinout_for_atdf_test() {
  let pinout_soic8 = mcvds_types.Pinout(mcvds_types.SOIC8, [])
  let pinout_soic14 = mcvds_types.Pinout(mcvds_types.SOIC14, [])
  let atdf_without_pinouts = mcvds_types.Atdf("", [], [], [])
  let atdf_with_soic8 = mcvds_types.Atdf("", [], [], [pinout_soic8])
  let atdf_with_soic14 = mcvds_types.Atdf("", [], [], [pinout_soic14])
  let atdf_with_both =
    mcvds_types.Atdf("", [], [], [pinout_soic8, pinout_soic14])
  [
    mcvds_ui.set_pinout_for_atdf(atdf_without_pinouts, None),
    mcvds_ui.set_pinout_for_atdf(atdf_without_pinouts, Some(pinout_soic14)),
    mcvds_ui.set_pinout_for_atdf(atdf_with_soic8, None),
    mcvds_ui.set_pinout_for_atdf(atdf_with_soic8, Some(pinout_soic14)),
    mcvds_ui.set_pinout_for_atdf(atdf_with_soic14, None),
    mcvds_ui.set_pinout_for_atdf(atdf_with_soic14, Some(pinout_soic14)),
    mcvds_ui.set_pinout_for_atdf(atdf_with_both, None),
    mcvds_ui.set_pinout_for_atdf(atdf_with_both, Some(pinout_soic14)),
  ]
  |> should.equal([
    None,
    None,
    Some(pinout_soic8),
    Some(pinout_soic8),
    Some(pinout_soic14),
    Some(pinout_soic14),
    Some(pinout_soic8),
    Some(pinout_soic14),
  ])
}
