private def it_parses(string, expected_value, file = __FILE__, line = __LINE__)
  it "parses #{string}", file, line do
    Supervisor::CommandParser.parse(string).should eq(expected_value)
  end
end

private def it_raises_on_parse(string, file = __FILE__, line = __LINE__)
  it "raises on parse #{string}", file, line do
    expect_raises Exception do
      Supervisor::CommandParser.parse(string)
    end
  end
end

module Supervisor
  describe CommandParser do

    it_parses %q(cmd a b c), {"cmd", ["a", "b", "c"]}
    it_parses %q(cmd "a x" b c), {"cmd", ["a x", "b", "c"]}
    it_parses %q(cmd "a\"b" c), {"cmd", [%q(a"b), "c"]}
    it_parses %q(cmd"xy" "a \t \" \b" "c \" d"), {"cmdxy", [%q(a \t " \b), %q(c " d)]}
    it_parses %q(cmd   a  "b c"), {"cmd", ["a", "b c"]}

    it_parses %q(cmd 'asd \" \t' "a b"), {"cmd", [%q(asd \" \t), "a b"]}
    it_parses %q(cmd'asd'"we" "b"), {"cmdasdwe", ["b"]}
    it_parses %q(cmd\"asd" "b"), { %q(cmd\asd), ["b"]}

    # raise on unclosed quotes
    it_raises_on_parse %q(cmd 'asd)
    it_raises_on_parse %q(cmd "asd)
    it_raises_on_parse %q(cmd "a b c" "d 'e)

    it_raises_on_parse "cmd\na b c"

  end
end
