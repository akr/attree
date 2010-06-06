class Attree
  include Attree::Util

  def initialize
    @parent = nil
    @parent_label = nil
    @srules = {} # label -> [rulemethod, param, strong_depends, weak_depends]
    @irules = {} # label -> label -> [rulemethod, param, strong_depends, weak_depends]
    @values = {} # label -> value
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

  def each_irule(label=nil, &block)
    if label
      h = @irules[label]
      if h
        h.each(&block)
      end
    else
      @irules.each {|l1, hh|
        hh.each {|l2, r|
          yield l1, l2, r
        }
      }
    end
  end

  def lookup_irule(label1, label2)
    h = @irules[label1]
    h ? h[label2] : nil
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
    if r = @srules[label]
      rulemethod, param, strong_depends, weak_depends = r
      return self, label, rulemethod, param, strong_depends, weak_depends
    end
    if @parent
      labelpath = "#{@parent_label}/#{label}"
      if r = @parent.lookup_irule(@parent_label, label)
        rulemethod, param, strong_depends, weak_depends = r
        return @parent, labelpath, rulemethod, param, strong_depends, weak_depends
      end
    end
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
    @srules[label] = [:rule_constant, value, [], []]
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
    target_ary = labelary.dup
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
    case target_ary.length
    when 1
      @srules[target] = [rulemethod, param, strong_depends, weak_depends]
    when 2
      @irules[target_ary[0]] ||= {}
      @irules[target_ary[0]][target_ary[1]] = [rulemethod, param, strong_depends, weak_depends]
    else
      raise ArgumentError, "target too deep: #{target.inspect}"
    end
  end

  def list_labels
    result = @srules.keys
    if @parent
      @parent.each_irule(@parent_label) {|l, r|
        result << l
      }
    end
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
