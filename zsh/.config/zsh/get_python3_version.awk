BEGIN {
    cmd = "python3 -V"
    while ((cmd | getline result) > 0) {
        out=result
    }

	split(out,s," ");
	split(s[2],o,".");
	# print "export","PYTHON_MAJOR_VERSION="o[1]"."o[2]"
	printf("export PYTHON_MAJOR_VERSION=\"%s.%s\"\n", o[1], o[2]);
}
