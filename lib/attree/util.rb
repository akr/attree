module Attree::Util
  module_function

  LABEL_PATTERN = %r{[a-zA-Z_][a-zA-Z_0-9]*}

  def validate_label(label)
    if %r{\A#{LABEL_PATTERN}\z}o !~ label
      raise ArgumentError, "invalid label: #{label.inspect}"
    end
  end

  def normalize_labelpath(labelpath)
    labelpath.scan(LABEL_PATTERN).join("/")
  end

  def labelpath_each(labelpath, &b)
    labelpath.scan(LABEL_PATTERN, &b)
  end

  def labelpath_to_a(labelpath)
    labelpath.scan(LABEL_PATTERN)
  end

  def obtainf(collection, index, *rest)
    if rest.empty?
      yield collection.fetch(index)
    else
      default, = rest
      begin
        v = collection.fetch(index)
      rescue IndexError
        return default
      end
      yield v
    end
  end
end
