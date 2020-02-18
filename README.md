# PHT.jl

Persistent Homology Transform is produced and maintained by \
Yossi Bokor and Katharine Turner \
<yossi.bokor@anu.edu.au> and <katharine.turner@anu.edu.au> \

This package provides an implementation of the Persistent Homology Transform, as defined in [Persistent Homology Transform for Modeling Shapes and Surfaces](https://arxiv.org/abs/1310.1030). 


## Installation
Currently, the best (only) way to install PHT is to download the code and import it into a Julia session. 

## Inputs
PHT computes the Persistent Homology Transform of simple, closed curves in $\mathbb{R}^2$ given a CSV file of ordered points sample from the curve in either a clockwise or anti-clockwise direction. You need to also specify a number of directions to use for the PHT.
