require File.join(File.dirname(__FILE__), "helper")

describe Component do
  describe "initialize()" do
    it "should raise an error without an :id option" do
      lambda { Component.new() }.should raise_error ArgumentError
    end
  end

  describe "id" do
    it "should be equal to the initally provided :id option" do
      comp = Component.new(:id => "fish")
      comp.id.should == "fish"
    end
  end
end
