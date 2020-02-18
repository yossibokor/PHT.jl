#= License
Copyright 2019, 2020 (c) Yossi Bokor Katharine Turner

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=#

__precompile__()


module PHT


#### Requirements ####
using CSV
using Hungarian
using DataFrames
using LinearAlgebra
using SparseArrays
using Eirene

#### Exports ####

export 	PHT,
		Recenter,
		Direction_Filtration,
		Evaluate_Barcode,
		Total_Rank_Exact,
		Total_Rank_Grid,
		Total_Rank_Auto,
		Combine_Rank_Functions,
		Average_Rank,
		Create_Heat_Map,
		Create_Average_Heat_Map,
		Average_Rank_Distance,
		PD_to_Discretised_Rank,
		Set_Mean_Zero,
		Weighted_Inner_Product,
		Weighted_Inner_Product_Matrix,
		Principal_Component_Scores,
		Average_Discretised_Rank
		
		

#### First some functions to recenter the curves ####
function Find_Center(points)
	n_p = size(stem_cell,1)
	
	c_x = Float64(0)
	c_y = Float64(0)
	
	for i in 1:n_p
		c_x += points[i,1]
		c_y += points[i,2]
	end
	
	return Float64(c_x/n_p), Float64(c_y/n_p)
end

function Recenter(points)
		
	center = Find_Center(points)
	
	for i in 1:size(points)[1]
		points[i,1] = points[i,1] - center[1]
		points[i,2] = points[i,2] - center[2]
	end
	
	return points
end


function Evaluate_Rank(barcode, point)
	
	n = size(barcode)[1]
	count = 0
	
	if point[2] < point[1]
		#return 0
	else
		for i in 1:n
			if barcode[i,1] <= point[1]
				if barcode[i,2] >= point[2]
					count +=1
				end
			end
		end
		return count
	end
end

function Total_Rank_Exact(barcode)

	rks = []

	
	n = size(barcode)[1]
	m = size(barcode)[1]
	b = copy(barcode)
	reshape(b, 2,n)
	for i in 1:n
		for j in 1:n
			if barcode[i,1] < barcode[j,1]
				if barcode[i,2] < barcode[j,2]
					b = vcat(b, [barcode[j,1] barcode[i,2]])
					m += 1
				end
			end
		end
	end
	
	
	for i in 1:size(b)[1]
		append!(rks, Evaluate_Rank(barcode, b[i,:]))
	end
	return b, rks

end


function Total_Rank_Grid(barcode, grid)

	rks = []

	b = grid
	
	for i in 1:size(b)[1]
		append!(rks, Evaluate_Rank(barcode, b[i,:]))
	end
	
	return rks

end

function Total_Rank_Auto(barcode, delta, top_right_corner)

	rks = []
	
	b = Array{Float64}(undef, 0, 2)
	x_number = ceil(top_right_corner[1]/delta)
	y_number = ceil(top_right_corner[2]/delta)
	
	for i in 1:x_number
		for j in (i-1):y_number
			b =vcat(b, [0+i*delta 0+j*delta])
		end
	end
	
	
	for i in 1:size(b)[1]
		append!(rks, Evaluate_Rank(barcode, b[i,:]))
	end
	return b, rks

end

function Combine_Rank_Functions(list_of_barcodes, grid)

	
	rks = zeros(size(grid)[1],1)
	
	
	n_b = length(list_of_barcodes)
	
	for i in 1:n_b
		rk_i = Total_Rank_Grid(list_of_barcodes[i], grid)
		rks = rks .+ rk_i
	end
	
	rks = rks/n_b
	
	return rks
end

function Average_Rank(x,y, list_of_barcodes)
	
	rk = 0
	n_b = length(list_of_barcodes)
	if y >= x
	for i in 1:n_b
			rk += Evaluate_Rank(list_of_barcodes[i], [x,y])
		end
		return rk/n_b
	else
		 return 0
	end
end

function Create_Average_Heat_Map(list_of_barcodes, x_list, y_list)
	
	f(x,y) =  begin
					if x > y
						return 0
					else
						return Average_Rank(x,y, list_of_barcodes)
					end
				end
				
	#Z = map(f, X, Y)

	p1 = contour(x_list, y_list, f, fill=true)

	return p1
end

function Create_Heat_Map(list_of_barcode, x_list, y_list)
	
	f(x,y) =  begin
					if x > y
						return 0
					else
						return Evaluate_Rank(barcode,[x,y])
					end
				end
				
	#Z = map(f, X, Y)

	p1 = contour(x_list, y_list, f, fill=true)

	return p1
end

function Average_Rank_Distance(list_1, list_2, x_list, y_list)

	
	f(x,y) =  begin
					if x > y
						return 0
					else
						difference = Average_Rank(x,y, list_1) - Average_Rank(x,y, list_2)
						return difference
					end
				end
				
	#Z = map(f, X, Y)

	p1 = contour(x_list, y_list, f, fill=true)

	return p1
	
end


# Let us do PCA for the rank functions using Kate and Vanessa's paper.
# So, I first need to calculate the pointwise norm
function PD_to_Discretised_Rank(persistence_diagram, grid_points) # grid_points should be an Mx2 matrix.
	grid_size = size(grid_points,1)
	
	v = Array{Float64}(undef, 1, grid_size)
	
	for i in 1:grid_size
		v[i] = Evaluate_Rank(persistence_diagram, grid_points[i,:])
	end
	
	return v
end

function Set_Mean_Zero(discretised_ranks)
	n_r = length(discretised_ranks)
	grid_size = size(discretised_ranks[1],1)
	
	for i in 1:n_r
		@assert size(discretised_ranks[i],1) == grid_size
	end
	
	mu = zeros(grid_size, 1)
	
	for i in 1:n_r
		mu = mu .+ discretised_ranks[i]
	end
	mu = mu./n_r

	normalised = copy(discretised_ranks)
	
	for i in 1:n_r
		normalised[i] = discretised_ranks[i] .- mu
	end
	
	return normalised
end

function Weighted_Inner_Product(disc_rank_1, disc_rank_2, weights)
	
	wip = sum((disc_rank_1.*disc_rank_2).*weights)

	return wip
end

function Weighted_Inner_Product_Matrix(discretised_ranks, weights)
	n_r = length(discretised_ranks)
	D = Array{Float64}(undef, n_r, n_r)
	
	for i in 1:n_r
		for j in i:n_r
			wip = Weighted_Inner_Product(discretised_ranks[i], discretised_ranks[j], weights)
			D[i,j] = wip
			D[j,i] = wip
		end
	end
	
	return D
end

function Principal_Component_Scores(inner_prod_matrix, dimension)
	F = LinearAlgebra.eigen(inner_prod_matrix, permute = false, scale=false) # this sorts the eigenvectors in ascending order
	n_r = size(inner_prod_matrix,1)
	lambda = Array{Float64}(undef, 1,dimension)
	w = Array{Float64}(undef, size(F.vectors)[1],dimension)
	n_v = length(F.values)

	for i in 1:dimension
		lambda[i] = F.values[n_v-i+1]
		w[:,i] = F.vectors[:,n_v-i+1]
	end
	
	s = Array{Float64}(undef, n_r,dimension)
	
	for i in 1:size(inner_prod_matrix,1)
		for j in 1:dimension
			
			den = sqrt(sum([w[k,j]*sum(w[l,j]*inner_prod_matrix[k,l] for l in 1:n_r) for k in 1:n_r]))
			numerator = sum(w[:,j].*inner_prod_matrix[:,i])
			s[i,j] = numerator/den
		end
	end
	return s
end

function Average_Discretised_Rank(list_of_disc_ranks)
	average = Array{Float64}(undef, size(list_of_disc_ranks[1]))
	n_r = length(list_of_disc_ranks)
	
	for i in n_r
		average = average .+ list_of_disc_ranks[i]
	end
	
	return average/n_r
end


function Direction_Filtration(ordered_points, direction; out = "barcode") # I should read the PHT paper and then figure out how to do the shifts for things which arent centered.
	# we need to create the information Eirene requires, so lets do that
	number_of_points = length(ordered_points[:,1]) #number of points
	heights = zeros(number_of_points) #empty array to be changed to heights for filtration
	fv = zeros(2*number_of_points) #blank fv Eirene
	for i in 1:number_of_points
		heights[i]= ordered_points[i,1]*direction[1] + ordered_points[i,2]*direction[2] #calculate heights in specificed direction
	end
	
	for i in 1:number_of_points
		fv[i]= heights[i] # for a point the filtration step is the height
	end
	
	for i in 1:(number_of_points-1)
		fv[(i+number_of_points)]=maximum([heights[i], heights[i+1]]) # for an edge between two adjacent points it enters when the 2nd of the two points does
	end
	
	fv[2*number_of_points] = maximum([heights[1] , heights[number_of_points]]) #last one is a special snowflake
	dv = [] # template dv for Eirene
	
	for i in 1:number_of_points
		append!(dv,0) # every point is 0 dimensional
	end
	
	for i in (1+number_of_points):(2*number_of_points)
		append!(dv,1) # edges are 1 dimensional
	end
	
	D = zeros((2*number_of_points, 2*number_of_points))
	
	for i in 1:number_of_points
		D[i,(i+number_of_points)]=1 # create boundary matrix and put in entries
	end
	
	for i in 1:(number_of_points-1)
		D[i, (i+number_of_points-1)]=1 # put in entries for boundary matrix
	end
	
	ev = [number_of_points, number_of_points] # template ev for Eirene
	
	S  = sparse(D) 	# converting as required for Eirene
	rv = S.rowval 	# converting as required for Eirene
	cp = S.colptr	# converting as required for Eirene
	C = eirene(rv=rv,cp=cp,ev=ev,fv=fv) # put it all into Eirene
	
	if out == "barcode"
		return barcode(C, dim=0)
	else
		return C
	end
end

 
#### Wrapper for the main function ####

function PHT(curve_points, number_of_directions) ##accepts an ARRAY of points
	
	angles = [n*pi/(number_of_directions/2) for n in 1:number_of_directions]
	directions = [[cos(x), sin(x)] for x in angles]
	
	pht = []
	for i in 1:number_of_directions
		pd = Direction_Filtration(data_n, directions[i])
		pht = vcat(pht, [pd])
	end

	return pht
end

end# module