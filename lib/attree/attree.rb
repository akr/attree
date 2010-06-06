class Attree
  include Attree::Util

  def initialize
    @parent = nil
    @parent_label = nil
    @primitive = {}  # label -> value
    @derivative = {} # label -> [{nil, value}, {:unknown, :known}, labelpath]
    @rule = {}       # labelpath -> [rulemethod, strong_depends, weak_depends]
  end
  attr_reader :parent, :parent_label

  def labelpath
    a = []
    n = self
    while parent = n.parent
      a << n.parent_label
      n = parent
    end
    a.reverse.join("/")
  end

  def fetch_known_child(label, *rest, &block)
    validate_label label
    if @primitive.include? label
      return @primitive.fetch(label)
    end
    if @derivative.include?(label)
      val, status, labelpath = @derivative.fetch(label)
      if status == :known
        return val
      end
    end
    {}.fetch(label, *rest, &block)
  end

  def get_known_child(label)
    fetch_known_child(label, nil)
  end

  def fetch_known(labelpath)
    labelpath_each(labelpath).inject(self) {|r, label|
      unless r.kind_of? Attree
        raise ArgumentError, "labelpath refer non-node: #{label.inspect} in #{labelpath.inspect}"
      end
      r.fetch_known_child(label)
    }
  end

  def define_child_value(label, value)
    validate_label label
    if @primitive.include? label
      raise ArgumentError, "value already defined: #{label}"
    end
    if @derivative.include? label
      val, status, labelpath = @derivative.fetch(label)
      raise ArgumentError, "rule already defined: #{labelpath}"
    end
    if value.kind_of?(Attree) && value.parent != nil
      raise ArgumentError, "already parent exists"
    end
    @primitive[label] = value
    value.instance_variable_set(:@parent, self)
    value.instance_variable_set(:@parent_label, label)
  end

  def define_rule(target, rulemethod, strong_depends=[], weak_depends=[])
    target = normalize_labelpath(target)
    strong_depends = strong_depends.map {|d| normalize_labelpath(d) }
    weak_depends = weak_depends.map {|d| normalize_labelpath(d) }
    labelary = labelpath_to_a(target)
    if labelary.empty?
      raise ArgumentError, "empty target"
    end
    lastlabel = labelary.pop
    target_node = fetch_known(labelary.join("/"))
    unless target_node.kind_of? Attree
      raise ArgumentError, "target is attribute: #{target}"
    end
    target_node_primitive = target_node.instance_variable_get(:@primitive)
    target_node_derivative = target_node.instance_variable_get(:@derivative)
    if target_node_primitive.include? lastlabel
      raise ArgumentError, "value already defined: #{target}"
    end
    if target_node_derivative.include? lastlabel
      raise ArgumentError, "rule already defined: #{target}"
    end
    target_node_derivative[lastlabel] = [nil, :unknown, target]
    @rule[target] = [rulemethod, strong_depends, weak_depends]
  end

  def primitive_labels
    @primitive.keys
  end

  def derivative_labels
    @derivative.keys
  end

  def list_labels
    @primitive.keys + @derivative.keys
  end

  def label_type(label)
    if @primitive.include? label
      :primitive
    elsif @derivative.include? label
      :derivative
    else
      nil
    end
  end

  def get_rule(label)
    value, status, labelpath = @derivative.fetch(label)
    labelary = labelpath_to_a(labelpath)
    n = self
    (labelary.length-1).times {
      n = n.parent
    }
    n_rule = n.instance_variable_get(:@rule)
    rulemethod, strong_depends, weak_depends = n_rule.fetch(labelpath)
    return n, labelpath, rulemethod, strong_depends, weak_depends
  end

  def fetch_known_lastref(labelpath)
    labelary = labelpath_to_a(labelpath)
    lastlabel = labelary.pop
    n = labelary.inject(self) {|r, label|
      unless r.kind_of? Attree
        raise ArgumentError, "labelpath refer non-node: #{label.inspect} in #{labelpath.inspect}"
      end
      r.fetch_known_child(label)
    }
    [n, lastlabel]
  end

  # xxx: this implementation is too naive.
  def make_value(labelpath)
    n, label = fetch_known_lastref(labelpath)
    case n.label_type(label)
    when :primitive
      n.fetch_known_child(label)
    when :derivative
      t, rule_labelpath, rulemethod, strong_depends, weak_depends = n.get_rule(label)
      h = {}
      strong_depends_values = strong_depends.map {|lp| h[lp] = t.make_value(lp) }
      weak_depends_values = weak_depends.map {|lp| h[lp] = t.make_value(lp) }
      t.send(rulemethod, h)
    else
      raise ArgumentError, "labelpath not defined: #{labelpath.inspect}"
    end
  end

  def [](labelpath)
    make_value(labelpath)
  end

end
