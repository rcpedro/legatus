class Hash
  def permit(*keys)
    self.slice(keys)
  end
end