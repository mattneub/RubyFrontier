module Biteme
  def self.method_missing(s, *args)
    if s == :whatever
      t = nil
      load (File.expand_path("~/Desktop/crud.rb"))
      whatever(1)
    else
      super s, *args
    end
  end
end
Biteme::whatever(1)
