#!/usr/bin/env python

import numpy as np
import sys

import matplotlib

matplotlib.use('Agg') # For headless use

import matplotlib.pyplot as plt
import os

rodinia_programs = [("Backprop", "backprop"),
                    ("CFD", "cfd"),
                    ("HotSpot", "hotspot"),
                    ("K-means", "kmeans"),
                    ("LavaMD", "lavaMD"),
                    ("Myocyte", "myocyte"),
                    ("NN", "nn"),
                    ("Pathfinder", "pathfinder"),
                    ("SRAD", "srad"),
                    ("LUD", "lud")]

accelerate_programs = [("Crystal", "crystal"),
                       ("Fluid", "fluid"),
                       ("Mandelbrot", "mandelbrot"),
                       ("N-body", "nbody"),
                       ("Tunnel", "tunnel")]

finpar_programs = [("LocVolCalib-small", "LocVolCalib_small"),
                   ("LocVolCalib-medium", "LocVolCalib_medium"),
                   ("LocVolCalib-large", "LocVolCalib_large"),
                   ("OptionPricing-small", "OptionPricing_small"),
                   ("OptionPricing-medium", "OptionPricing_medium"),
                   ("OptionPricing-large", "OptionPricing_large")]

parboil_programs = [("MRI-Q", "mri-q"),
                    ("SGEMM", "sgemm"),
                    ("Stencil", "stencil"),
                    ("TPACF", "tpacf")]

outdir=sys.argv[1]

def ref_filename_closure(ref):
    return lambda d, filename: os.path.join(d, filename + '-' + ref + '.avgtime')

def fut_filename(d, filename):
    return os.path.join(d, filename + '-futhark.avgtime')

def get_ref_avgtime(d, ref_filename, filename):
    with open(ref_filename(d, filename)) as f:
        return '%.1f' % float(f.read())

def get_fut_avgtime(d, ref_filename, filename):
    with open(fut_filename(d, filename)) as f:
        return '%.1f' % float(f.read())

def get_avgtimes(d, ref_filename, filename):
    return (get_ref_avgtime(d, ref_filename, filename),
            get_fut_avgtime(d, ref_filename, filename))

def put(filename, ref, fut, auxref, auxfut):
    with open(outdir + '/' + filename + '-ref.tex', 'w') as f:
        f.write(ref)
    with open(outdir + '/' + filename + '-futhark.tex', 'w') as f:
        f.write(fut)
    with open(outdir + '/' + filename + '-auxref.tex', 'w') as f:
        f.write(auxref)
    with open(outdir + '/' + filename + '-auxfuthark.tex', 'w') as f:
        f.write(auxfut)

def table_info_closure(ref_filename):
    def table_info(x):
        name, filename = x
        try:
            (ref_avgtime, fut_avgtime) = get_avgtimes('runtimes', ref_filename, filename)
            try:
                aux_fut_avgtime = get_fut_avgtime('aux_runtimes', ref_filename, filename)
                try:
                    aux_ref_avgtime = get_ref_avgtime('aux_runtimes', ref_filename, filename)
                    put(filename, ref_avgtime, fut_avgtime, aux_ref_avgtime, aux_fut_avgtime)
                except:
                    put(filename, ref_avgtime, fut_avgtime, '---', aux_fut_avgtime)
            except:
                put(filename, ref_avgtime, fut_avgtime, '---', '---')
        except Exception as e:
            print(e)
            sys.stderr.write('Skipping %s as the file could not be opened.\n' % name)
            return None
    return table_info

map(table_info_closure(ref_filename_closure('rodinia')), rodinia_programs)
map(table_info_closure(ref_filename_closure('finpar')), finpar_programs)
map(table_info_closure(ref_filename_closure('parboil')), parboil_programs)
map(table_info_closure(ref_filename_closure('accelerate')), accelerate_programs)
