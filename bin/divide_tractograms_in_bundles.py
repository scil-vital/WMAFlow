#!/usr/bin/env python3
# -*- coding: utf-8 -*-


import argparse
import json
import logging
from os.path import basename, join

import numpy as np
from scilpy.io.utils import (
    add_overwrite_arg,
    add_verbose_arg,
    assert_inputs_exist,
    assert_output_dirs_exist_and_empty,
)

from vtk_util import read_vtk, save_vtk


def _build_arg_parser():

    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawTextHelpFormatter)
    p.add_argument("in_tractogram", help="VTK/VTP tractogram.")
    p.add_argument("in_json", help="JSON with division information")
    p.add_argument("out_folder", help="Out folder")

    add_verbose_arg(p)
    add_overwrite_arg(p)

    return p


def main():
    parser = _build_arg_parser()
    args = parser.parse_args()

    if args.verbose:
        logging.basicConfig(level=logging.INFO)

    assert_inputs_exist(parser, [args.in_tractogram, args.in_json])
    assert_output_dirs_exist_and_empty(parser, args, args.out_folder)

    if args.verbose:
        logging.basicConfig(level=logging.INFO)

    tractogram = read_vtk(args.in_tractogram)[0]

    with open(args.in_json, "r") as f:
        division_info = json.load(f)

    ids_list = list(np.zeros(len(division_info)))
    for k, v in division_info.items():
        ids_list[v["order"]] = (k, v["length"])

    count = 0

    for name, length in ids_list:
        if length > 0:
            bundle = tractogram[count : count + length]
            filename = basename(name).split(".")[0]
            save_vtk(join(args.out_folder, filename + ".vtk"), np.array(bundle))
        count += length


if __name__ == "__main__":
    main()
