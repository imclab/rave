require 'rubygems'
require 'rave'

module MyRaveRobot
  class Robot < Rave::Models::Robot
    #This is a very simple robot that tries to tone down yelling in waves
    def blip_submitted(event, context)
      blip = event.blip # Blip that was submitted.
      text = blip.content
      text.gsub!(/(\s*)([^!\.]+)/) { $1 + $2.capitalize } # Capitalize sentances.
      text.gsub!(/!+/, '.') # Calm down exclaimations.
      blip.set_text(text) if text != blip.content
    end
  end
end
