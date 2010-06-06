class Attree
  include Attree::Util

  def initialize
    @parent = nil
    @parent_label = nil
    @search_levels = 0
    @rules = {}      # labelpath -> [rulemethod, param, strong_depends, weak_depends]
    @values = {}     # label -> value
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

  def each_rule(&block)
    @rules.each(&block)
  end

  def fetch_known_child(label, *rest, &block)
    validate_label label
    if @values.include? label
      return @values.fetch(label)
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

  def get_rule(label)
    n = self
    labelary = [label]
    (@search_levels+1).times {
      labelpath = labelary.join("/")
      n_rules = n.instance_variable_get(:@rules)
      if n_rules.include? labelpath
        rulemethod, param, strong_depends, weak_depends = n_rules.fetch(labelpath)
        return n, labelpath, rulemethod, param, strong_depends, weak_depends
      end
      labelary.unshift n.parent_label
      n = n.parent
    }
    nil
  end

  def define_child_value(label, value)
    validate_label label
    if value.kind_of?(Attree) && value.parent != nil
      raise ArgumentError, "already parent exists"
    end
    r = get_rule(label)
    if r
      n, labelpath, rulemethod, strong_depends, weak_depends = r
      raise ArgumentError, "rule already defined: #{labelpath}"
    end
    @rules[label] = [:rule_constant, value, [], []]
    @values[label] = value
    value.instance_variable_set(:@parent, self)
    value.instance_variable_set(:@parent_label, label)
  end

  def rule_constant(target, value, depends)
    value
  end

  def define_rule(target, rulemethod, param=nil, strong_depends=[], weak_depends=[])
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
    if target_node.get_rule(lastlabel)
      raise ArgumentError, "rule already defined: #{target}"
    end
    target_node_search_levels = target_node.instance_variable_get(:@search_levels)
    if target_node_search_levels < labelary.length
      target_node.instance_variable_set(:@search_levels, labelary.length)
    end
    @rules[target] = [rulemethod, param, strong_depends, weak_depends]
  end

  def list_labels
    result = []
    n = self
    labelary = []
    (@search_levels+1).times {
      labelpath = labelary.join("/")
      n_rules = n.instance_variable_get(:@rules)
      labels = n_rules.map {|lp, _|
        la = labelpath_to_a(lp)
        last = la.pop
        [la, last]
      }.reject {|prefix, lastlabel|
        prefix != labelary
      }.map {|prefix, lastlabel|
        lastlabel
      }
      result.concat labels
      labelary.unshift n.parent_label
      n = n.parent
    }
    result
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
    n.fetch_known_child(label) {
      if r = get_rule(label)
        t, labelpath, rulemethod, param, strong_depends, weak_depends = r
        h = {}
        strong_depends_values = strong_depends.map {|lp| h[lp] = t.make_value(lp) }
        weak_depends_values = weak_depends.map {|lp| h[lp] = t.make_value(lp) }
        t.send(rulemethod, param, h)
      else
        raise ArgumentError, "labelpath not defined: #{labelpath.inspect}"
      end
    }
  end

  def [](labelpath)
    make_value(labelpath)
  end

end
