# perl-func-parse-simple
a simple perl function parser
这是一个解析perl函数调用结构的脚本，能够根据文本上下文分析，不支持一些标准库的函数。使用方法非常简单，在命令行输入

perl parse_tool.pl

运行脚本，然后输入

func

按照提示输入perl脚本的位置，就可以获得函数调用结构，该结果以hash的形式呈现。
