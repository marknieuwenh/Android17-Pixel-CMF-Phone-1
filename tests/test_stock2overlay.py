"""Tests for tools/stock2overlay.py. Run: python3 -m unittest discover tests"""

import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("stock2overlay", ROOT / "tools" / "stock2overlay.py")
s2o = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s2o)

# Real `aapt2 dump resources` output of an overlay with one value of each kind.
DUMP = (ROOT / "tests" / "fixtures" / "aapt2-dump-resources.txt").read_text()


class ParseDumpTest(unittest.TestCase):
    def setUp(self):
        self.values = {(t, n, q): v for t, n, q, v in s2o.parse_dump(DUMP)}

    def test_scalar_values(self):
        self.assertEqual(self.values[("bool", "config_dozeAlwaysOnDisplayAvailable", "")], "true")
        self.assertEqual(self.values[("integer", "config_defaultPeakRefreshRate", "")], "120")

    def test_qualified_values(self):
        self.assertEqual(self.values[("dimen", "status_bar_height_portrait", "")], "32.500000dp")
        self.assertEqual(self.values[("dimen", "status_bar_height_portrait", "land")], "24.000000dp")

    def test_arrays(self):
        self.assertEqual(self.values[("array", "config_autoBrightnessLevels", "")], ("array", "[2, 10, 300]"))


class ConvertTest(unittest.TestCase):
    def test_dimen_units_are_trimmed(self):
        self.assertEqual(s2o.convert("dimen", "104.000000px"), ("dimen", "", "104px"))
        self.assertEqual(s2o.convert("dimen", "32.500000dp"), ("dimen", "", "32.5dp"))

    def test_unitless_dimen_is_float_item(self):
        self.assertEqual(s2o.convert("dimen", "0.0039"), ("item", ' type="dimen" format="float"', "0.0039"))

    def test_references_are_skipped(self):
        self.assertIsNone(s2o.convert("integer", "@0x7f010000"))

    def test_string_is_escaped(self):
        tag, _, body = s2o.convert("string", '"M 0,0 H -20 V 90 Z @dp"')
        self.assertEqual((tag, body), ("string", '"M 0,0 H -20 V 90 Z @dp"'))

    def test_array_kinds(self):
        self.assertEqual(s2o.convert_array("[2, 10]")[0], "integer-array")
        self.assertEqual(s2o.convert_array("[2.5, 10]")[0], "array")
        self.assertEqual(s2o.convert_array('["a b", "c"]')[0], "string-array")
        self.assertIsNone(s2o.convert_array("[@0x7f010000]"))


class RulesTest(unittest.TestCase):
    def setUp(self):
        self.rules = s2o.load_rules(ROOT / "config" / "carry-over.conf")

    def test_hardware_values_are_carried(self):
        for rtype, name in [("string", "config_mainBuiltInDisplayCutout"),
                            ("array", "config_autoBrightnessLevels"),
                            ("dimen", "rounded_corner_radius"),
                            ("integer", "config_defaultPeakRefreshRate"),
                            ("array", "config_udfps_sensor_props")]:
            self.assertTrue(s2o.allowed(self.rules, "android", rtype, name), name)

    def test_nothing_components_are_not_carried(self):
        for rtype, name in [("string", "config_recentsComponentName"),
                            ("string", "config_dozeComponent"),
                            ("color", "config_foo")]:
            self.assertFalse(s2o.allowed(self.rules, "android", rtype, name), name)

    def test_unknown_targets_are_not_carried(self):
        self.assertFalse(s2o.allowed(self.rules, "com.nothing.launcher", "dimen", "rounded_corner_radius"))


if __name__ == "__main__":
    unittest.main()
