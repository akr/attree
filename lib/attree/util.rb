module Attree::Util
  module_function

  def validate_label(label)
    if %r{/} =~ label
      raise ArgumentError, "invalid label: #{label.inspect}"
    end
  end

  def normalize_labelpath(labelpath)
    labelpath.scan(%r{[^/]+}).join("/")
  end

  def labelpath_each(labelpath, &b)
    labelpath.scan(%r{[^/]+}, &b)
  end

  def labelpath_to_a(labelpath)
    labelpath.scan(%r{[^/]+})
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
