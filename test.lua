
gsub = string.gsub

print(gsub("ho la", "(%w+)", "%1 %1"))
print(gsub("ho la", "%w+", "%0 %0", 1))
print(gsub("un dos tres cua", "(%w+)%s*(%w+)", "%2 %1"))
print(gsub("hola $lua$", "%$(.-)%$", function (s) return s:upper() end))
print(gsub("$name-$version.tgz", "%$(%w+)", {name="lua", version="5.3"}))