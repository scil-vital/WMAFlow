# WMA Flow
===================

WMA Flow reimplements python scripts from the WMA github repository for tractogram bundling. See https://github.com/SlicerDMRI/whitematteranalysis.

Create a virtual environment with **python3.7** and pip install the wma github repository:

```
pip install git+https://github.com/SlicerDMRI/whitematteranalysis.git
```

Run `wm_quality_control_tractography.py --help` to test if the installation is successful.

## Software prerequisites
   - Install [3D Slicer](https://download.slicer.org/)
      > 3D Slicer is an open source software platform for medical image informatics, image processing, and three-dimensional visualization.
   - Install [SlicerDMRI](http://dmri.slicer.org/download/)
      > SlicerDMRI is an open-source project to improve and extend diffusion magnetic resonance imaging software in 3D Slicer.
   - Install [whitematteranalysis (WMA)](https://github.com/SlicerDMRI/whitematteranalysis#wma-installation)
      > WMA is an open source software package for data-driven fiber clustering white matter parcellation.

## Download tutorial data (The atlas is there)
   - Download the tutorial data package ([WMA_tutorial_data.zip](https://www.dropbox.com/s/beju3c0g9jqw5uj/WMA_tutorial_data.zip?dl=0), ~2.5GB)

## Notes
 All files must be converted in VTK format

Requirements
------------

* Nextflow
* Python 3.7
* Slicer

Usage
-----

See *USAGE* or run `nextflow run main.nf --help`

