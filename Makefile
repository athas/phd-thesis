PAPERPDF=thesis.pdf
all: $(PAPERPDF)

PDFLATEX        = pdflatex -halt-on-error
#latex

%.pdf: %.tex Makefile
	$(PDFLATEX) $<
	biber $*
	$(PDFLATEX) $<
	$(PDFLATEX) $<
	rm -f *~ *.bbl *.log *.blg *.aux *.out

clean:
	rm -f *~ *.bbl *.log *.blg *.aux *.out $(PAPERPDF)
