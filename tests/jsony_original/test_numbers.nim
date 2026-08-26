import holo_json

block:
  doAssert "true".fromJsonAs(bool) == true
  doAssert "false".fromJsonAs(bool) == false
  doAssert " true  ".fromJsonAs(bool) == true
  doAssert "  false    ".fromJsonAs(bool) == false

  doAssert "1".fromJsonAs(int) == 1
  doAssert "12".fromJsonAs(int) == 12
  doAssert "  123  ".fromJsonAs(int) == 123

  doAssert " 123 ".fromJsonAs(int8) == 123
  doAssert " 123 ".fromJsonAs(uint8) == 123
  doAssert " 123 ".fromJsonAs(int16) == 123
  doAssert " 123 ".fromJsonAs(uint16) == 123
  doAssert " 123 ".fromJsonAs(int32) == 123
  doAssert " 123 ".fromJsonAs(uint32) == 123
  doAssert " 123 ".fromJsonAs(int64) == 123
  doAssert " 123 ".fromJsonAs(uint64) == 123

  doAssert " -99 ".fromJsonAs(int8) == -99
  doAssert " -99 ".fromJsonAs(int16) == -99
  doAssert " -99 ".fromJsonAs(int32) == -99
  doAssert " -99 ".fromJsonAs(int64) == -99

  doAssert " +99 ".fromJsonAs(int8) == 99
  doAssert " +99 ".fromJsonAs(int16) == 99
  doAssert " +99 ".fromJsonAs(int32) == 99
  doAssert " +99 ".fromJsonAs(int64) == 99

  doAssert " 1.25 ".fromJsonAs(float32) == 1.25
  doAssert " 1.25 ".fromJsonAs(float32) == 1.25
  doAssert " +1.25 ".fromJsonAs(float64) == 1.25
  doAssert " +1.25 ".fromJsonAs(float64) == 1.25
  doAssert " -1.25 ".fromJsonAs(float64) == -1.25
  doAssert " -1.25 ".fromJsonAs(float64) == -1.25

  doAssert " 1.34E3 ".fromJsonAs(float32) == 1.34E3
  doAssert " 1.34E3 ".fromJsonAs(float32) == 1.34E3
  doAssert " +1.34E3 ".fromJsonAs(float64) == 1.34E3
  doAssert " +1.34E3 ".fromJsonAs(float64) == 1.34E3
  doAssert " -1.34E3 ".fromJsonAs(float64) == -1.34E3
  doAssert " -1.34E3 ".fromJsonAs(float64) == -1.34E3

  doAssert "9e-8".fromJsonAs(float64) == 9e-8

block:
  doAssert "[1, 2, 3]".fromJsonAs(seq[int]) == @[1, 2, 3]
  doAssert """["hi", "bye", "maybe"]""".fromJsonAs(seq[string]) ==
    @["hi", "bye", "maybe"]
  doAssert """[["hi", "bye"], ["maybe"], []]""".fromJsonAs(seq[seq[string]]) ==
    @[@["hi", "bye"], @["maybe"], @[]]
