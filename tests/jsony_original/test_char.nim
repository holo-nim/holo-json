import holo_json

doAssert """ "a" """.fromJsonAs(char) == 'a'
doAssert """["a"]""".fromJsonAs(seq[char]) == @['a']
doAssert """["a", "b", "c"]""".fromJsonAs(seq[char]) == @['a', 'b', 'c']
doAssert 'a'.toJson() == """"a""""
doAssert 'b'.toJson() == """"b""""
