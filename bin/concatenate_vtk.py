#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import argparse
import json
import logging
from os.path import dirname, basename, join

import numpy as np
from scilpy.io.utils import (
    add_overwrite_arg,
    add_verbose_arg,
    assert_inputs_exist,
    assert_outputs_exist,
)
from tqdm import tqdm

from vtk_util import read_vtk, save_vtk


def _build_arg_parser():

    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("in_tractograms", help="VTK/VTP bundles to concatenate.", nargs="+")
    p.add_argument("out_tractogram", help="VTK/VTP concatenated tractogram.")

    add_verbose_arg(p)
    add_overwrite_arg(p)

    return p


def main():
    parser = _build_arg_parser()
    args = parser.parse_args()

    if args.verbose:
        logging.basicConfig(level=logging.INFO)

    assert_inputs_exist(parser, args.in_tractograms)
    assert_outputs_exist(parser, args, args.out_tractogram)

    if args.verbose:
        logging.basicConfig(level=logging.INFO)

    streamlines = []
    ids = {}
    for i, f in enumerate(tqdm(args.in_tractograms)):
        s = read_vtk(f)[0]
        streamlines.extend(s)
        ids[basename(f)] = {"order": i, "length": len(s)}

    number_of_streamline = len(streamlines)
    print(f"Number of streamlines: {number_of_streamline}")

    save_vtk(args.out_tractogram, np.array(streamlines))

    pathname = dirname(args.out_tractogram)
    filename = basename(args.out_tractogram).split(".")[0]

    with open(join(pathname, filename + ".json"), "w") as f:
        json.dump(ids, f)


if __name__ == "__main__":
    main()
