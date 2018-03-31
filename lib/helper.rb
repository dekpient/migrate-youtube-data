def confirm?(text)
  if ENV.fetch('YES_TO_ALL', false)
    puts text
    return true
  end
  printf "#{text}. Yes? (y/n): "
  prompt = gets.chomp
  prompt.casecmp? 'y'
end
