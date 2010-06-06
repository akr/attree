require 'test/unit'
require 'attree'

class TestCalc < Test::Unit::TestCase

  class Lit < Attree
    def initialize(result)
      super()
      define_child_value("result", result)
    end
  end
  def Lit(result) Lit.new(result) end

  class Add < Attree
    def initialize(lhs, rhs)
      super()
      define_child_value("lhs", lhs)
      define_child_value("rhs", rhs)
      define_rule("result", :rule_add, nil, %w[lhs/result rhs/result])
    end

    def rule_add(param, depends)
      depends["lhs/result"] + depends["rhs/result"]
    end
  end
  def Add(lhs, rhs) Add.new(lhs, rhs) end

  def test_lit
    assert_equal(1, Lit(1)["result"])
  end

  def test_add
    assert_equal(3, Add(Lit(1), Lit(2))["result"])
  end
end
