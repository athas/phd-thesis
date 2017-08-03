PAPERPDF=thesis.pdf
all: $(PAPERPDF)

PDFLATEX        = xelatex -halt-on-error

%.pdf: %.tex Makefile $(shell ls *.tex)
	$(PDFLATEX) $<
	biber $*
	$(PDFLATEX) $<
	$(PDFLATEX) $<
	rm -f *~ *.bbl *.log *.blg *.aux *.out

clean:
	rm -f *~ *.bbl *.log *.blg *.aux *.out $(PAPERPDF)
