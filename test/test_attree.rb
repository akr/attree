require 'test/unit'
require 'attree'

class TestAttree < Test::Unit::TestCase
  def test_fetch_known_child_nothing
    t = Attree.new
    assert_raise(KeyError) { t.fetch_known_child("a") }
    assert_equal(1, t.fetch_known_child("a", 1))
    assert_equal(2, t.fetch_known_child("b") { 2 })
    t.fetch_known_child("c") {|k| assert_equal("c", k) }
  end

  def test_fetch_known_child_value
    t = Attree.new
    t.define_child_value("d", 3)
    assert_equal(3, t.fetch_known_child("d"))
  end

  def test_get_known_child
    t = Attree.new
    assert_equal(nil, t.get_known_child("e"))
    t.define_child_value("e", 4)
    assert_equal(4, t.get_known_child("e"))
  end

  def test_fetch_known
    t1 = Attree.new
    t2 = Attree.new
    t3 = Attree.new
    t1.define_child_value("f", t2)
    t2.define_child_value("g", t3)
    t3.define_child_value("h", 5)
    assert_equal(t1, t1.fetch_known(""))
    assert_equal(t2, t1.fetch_known("f"))
    assert_equal(t3, t1.fetch_known("f/g"))
    assert_equal(5, t1.fetch_known("f/g/h"))
    assert_raise(KeyError) { t1.fetch_known("f/x") }
    assert_raise(KeyError) { t1.fetch_known("f/g/x") }
    assert_raise(ArgumentError) { t1.fetch_known("f/g/h/x") }
  end

  def test_define_rule_duplicate
    t = Attree.new
    t.define_child_value("i", 4)
    t.define_rule("j", :dummymethod)
    assert_raise(ArgumentError) { t.define_rule("i", :dummymethod) }
    assert_raise(ArgumentError) { t.define_rule("j", :dummymethod) }
  end

  def test_define_child_value_duplicate
    t = Attree.new
    t.define_child_value("k", 5)
    t.define_rule("l", :dummymethod)
    assert_raise(ArgumentError) { t.define_child_value("k", 6) }
    assert_raise(ArgumentError) { t.define_child_value("l", 7) }
  end

  def test_parent
    t = Attree.new
    assert_equal(nil, t.parent)
    t2 = Attree.new
    assert_equal(nil, t2.parent)
    t.define_child_value("l", t2)
    assert_equal(t, t2.parent)
    assert_raise(ArgumentError) { t.define_child_value("m", t2) }
  end

  def test_labelpath
    t = Attree.new
    assert_equal("", t.labelpath)
    t2 = Attree.new
    t.define_child_value("m", t2)
    assert_equal("m", t2.labelpath)
    t3 = Attree.new
    t2.define_child_value("n", t3)
    assert_equal("m/n", t3.labelpath)
  end

  def test_list_labels
    t = Attree.new
    t.define_child_value("s", 4)
    t.define_rule("t", :dummymethod)
    assert_equal(["s", "t"], t.list_labels.sort)
  end

  def test_get_rule
    t1 = Attree.new
    t2 = Attree.new
    t1.define_child_value("u", t2)
    t1.define_rule("u/v", :w)
    t, labelpath, rulemethod, param, strong_depends, weak_depends = t2.get_rule("v")
    assert_same(t1, t)
    assert_equal("u/v", labelpath)
    assert_equal(:w, rulemethod)
    assert_equal(nil, param)
    assert_equal([], strong_depends)
    assert_equal([], weak_depends)
  end

  def test_fetch_known_lastref
    t1 = Attree.new
    t2 = Attree.new
    t3 = Attree.new
    t1.define_child_value("x", t2)
    t2.define_child_value("y", t3)
    assert_equal([t1, "x"], t1.fetch_known_lastref("x"))
    assert_equal([t2, "y"], t1.fetch_known_lastref("x/y"))
    assert_equal([t3, "z"], t1.fetch_known_lastref("x/y/z"))
  end

  def test_each_rule
    t = Attree.new
    t.define_child_value("s", 4)
    t.define_rule("t", :dummymethod)
    rules = []
    t.each_rule {|rule|
      rules << rule
    }
    labels = rules.map {|labelpath, (rulemethod, param, strong_depends, weak_depends)| labelpath }
    assert_equal(["s", "t"], labels.sort)
  end

end
