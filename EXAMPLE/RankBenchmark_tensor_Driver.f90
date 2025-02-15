!> @file
!> @brief This example generates a random LR product, or reads a full matrix from disk, and compress it using entry-valuation-based APIs
!> @details Note that instead of the use of precision dependent subroutine/module/type names "z_", one can also use the following \n
!> #define DAT 0 \n
!> #include "zButterflyPACK_config.fi" \n
!> which will macro replace precision-independent subroutine/module/type names "X" with "z_X" defined in SRC_DOUBLECOMLEX with double-complex precision

module APPLICATION_MODULE_RankBenchmark_t
use z_BPACK_DEFS
implicit none

	!**** define your application-related variables here
	type quant_app
		real(kind=8), allocatable :: locations_m(:,:),locations_n(:,:) ! geometrical points
		integer,allocatable:: permutation_m(:,:),permutation_n(:,:)
		integer:: rank
		integer,allocatable:: Nunk_m(:),Nunk_n(:)
		integer:: Ndim
		integer:: tst=1
		real(kind=8)::wavelen,zdist
	end type quant_app

contains



	!**** user-defined subroutine to sample Z_mn as full matrix
	subroutine Zelem_MD_User(Ndim, m,n,value,quant)
		use z_BPACK_DEFS
		use z_MISC_Utilities
		implicit none

		class(*),pointer :: quant
		integer, INTENT(IN):: Ndim
		integer, INTENT(IN):: m(Ndim),n(Ndim)
		complex(kind=8)::value
		integer ii, dim_i

		real(kind=8)::pos_o(Ndim),pos_s(Ndim), dist, waven, dotp, sx,cx,xk,kr,theta,phi,d,f,x,y,tau,p,h,k(3)

		select TYPE(quant)
		type is (quant_app)
			do dim_i=1,Ndim
				pos_o(dim_i) = quant%locations_m(dim_i,m(dim_i))
				pos_s(dim_i) = quant%locations_n(dim_i,n(dim_i))
			enddo
			if(quant%tst==1)then
				dist = sqrt(sum((pos_o-pos_s)**2d0))
				waven=2*BPACK_pi/quant%wavelen
				value = EXP(-BPACK_junit*waven*dist)/dist
			elseif(quant%tst==2)then
				dist = sqrt(sum((pos_o-pos_s)**2d0) + quant%zdist**2d0)
				waven=2*BPACK_pi/quant%wavelen
				value = EXP(-BPACK_junit*waven*dist)/dist
			elseif(quant%tst==3)then
				dist = sqrt(sum((pos_o-pos_s)**2d0))
				waven=2*BPACK_pi/quant%wavelen
				value = EXP(-BPACK_junit*waven*dist)/dist
			elseif(quant%tst==4)then
				do dim_i=1,Ndim
					pos_s(dim_i) = quant%locations_n(dim_i,z_bit_reverse(n(dim_i),INT((log(dble(quant%Nunk_n(dim_i))) / log(2d0)))))
					pos_o(dim_i) = quant%locations_m(dim_i,z_bit_reverse(m(dim_i),INT((log(dble(quant%Nunk_m(dim_i))) / log(2d0)))))
				enddo
				dotp = dot_product(pos_o,pos_s)
				value = EXP(-2*BPACK_pi*BPACK_junit*dotp)
			elseif(quant%tst==5)then
				xk = dot_product(pos_o,pos_s)
				sx = (2+sin(2*BPACK_pi*pos_o(1))*sin(2*BPACK_pi*pos_o(2)))/16d0;
				cx = (2+cos(2*BPACK_pi*pos_o(1))*cos(2*BPACK_pi*pos_o(2)))/16d0;
				kr = sqrt(sx**2*pos_s(1)**2 + cx**2*pos_s(2)**2);
				value = EXP(2*BPACK_pi*BPACK_junit*(xk + kr))
				! value = cos(2*BPACK_pi*(xk + kr))+Im*sin(2*BPACK_pi*(xk + kr));
			elseif(quant%tst==6)then
				theta = pos_o(1)*BPACK_pi/8d0 ! only constrain theta from 0 to pi/8, otherwise the phase function becomes unbounded
				phi = pos_o(2)*2*BPACK_pi
				d = pos_o(3)
				x = pos_s(1)
				y = pos_s(2)
				f = pos_s(3) * size(quant%locations_n,2)
				kr = f*(-tan(theta)*cos(phi)*x - tan(theta)*sin(phi)*y + d/cos(theta))
				value = EXP(2*BPACK_pi*BPACK_junit*kr)
			elseif(quant%tst==7)then
				theta = pos_o(1)*BPACK_pi/4d0 ! only constrain theta from 0 to pi/4, otherwise the phase function becomes unbounded
				d = pos_o(2)
				x = pos_s(1)
				f = pos_s(2) * size(quant%locations_n,2)
				kr = f*(-tan(theta)*x + d/cos(theta))
				value = EXP(2*BPACK_pi*BPACK_junit*kr)
			elseif(quant%tst==8)then
				tau = pos_o(1)
				p = pos_o(2)
				h = pos_s(1)
				f = pos_s(2) * size(quant%locations_n,2)/10
				kr = f*sqrt(tau**2d0+p**2d0*h**2d0)
				value = EXP(2*BPACK_pi*BPACK_junit*kr)
			elseif(quant%tst==9)then

				! do dim_i=1,Ndim
				! 	pos_s(dim_i) = quant%locations_n(dim_i,z_bit_reverse(n(dim_i),INT((log(dble(quant%Nunk_n(dim_i))) / log(2d0)))))
				! 	pos_o(dim_i) = quant%locations_m(dim_i,z_bit_reverse(m(dim_i),INT((log(dble(quant%Nunk_m(dim_i))) / log(2d0)))))
				! enddo

				k = pos_s

				! k(1) = sqrt(2d0)/2d0* size(quant%locations_n,2) * pos_s(1)*sin(BPACK_pi*pos_s(2))*cos(2*BPACK_pi*pos_s(3))
				! k(2) = sqrt(2d0)/2d0* size(quant%locations_n,2) * pos_s(1)*sin(BPACK_pi*pos_s(2))*sin(2*BPACK_pi*pos_s(3))
				! k(3) = sqrt(2d0)/2d0* size(quant%locations_n,2) * pos_s(1)*cos(BPACK_pi*pos_s(2))

				cx = (3d0+sin(2*BPACK_pi*pos_o(1))*sin(2*BPACK_pi*pos_o(2))*sin(2*BPACK_pi*pos_o(3)))/100d0;
				xk = dot_product(pos_o,k)
				kr = xk+cx*sqrt(sum((k)**2d0))
				value = EXP(2*BPACK_pi*BPACK_junit*kr)
			elseif(quant%tst==10)then
				do dim_i=1,Ndim
					! pos_s(dim_i) = quant%locations_n(dim_i,z_bit_reverse(n(dim_i),INT((log(dble(quant%Nunk_n(dim_i))) / log(2d0)))))
					! pos_o(dim_i) = quant%locations_m(dim_i,z_bit_reverse(m(dim_i),INT((log(dble(quant%Nunk_m(dim_i))) / log(2d0)))))

					pos_s(dim_i) = quant%locations_n(dim_i,n(dim_i))
					pos_o(dim_i) = quant%locations_m(dim_i,m(dim_i))					
				enddo
				dotp = dot_product(pos_o,pos_s)
				value = EXP(-2*BPACK_pi*BPACK_junit*dotp)			
			else
				write(*,*)'tst unknown'
			endif

		class default
			write(*,*)"unexpected type"
			stop
		end select
	end subroutine Zelem_MD_User


	!**** user-defined subroutine to sample Z_mn as full matrix (note that this is for the BF interface not for the BPACK interface)
	subroutine ZBelem_MD_User(Ndim, m, n,value_e,quant)
		use z_BPACK_DEFS
		implicit none

		class(*),pointer :: quant
		integer, INTENT(IN):: Ndim
		integer, INTENT(IN):: m(Ndim),n(Ndim)
		complex(kind=8)::value_e
		integer ii,dim_i, m1(Ndim),n1(Ndim)

		if(m(1)>0)then
			m1=m
			n1=-n
		else
			m1=n
			n1=-m
		endif

		!!! m,n still need to convert to the original order, using new2old of mshr and mshc
		select TYPE(quant)
		type is (quant_app)
			do dim_i=1,Ndim
				m1(dim_i)=quant%permutation_m(m1(dim_i),dim_i)
				n1(dim_i)=quant%permutation_n(n1(dim_i),dim_i)
			enddo
		class default
			write(*,*)"unexpected type"
			stop
		end select

		call Zelem_MD_User(Ndim,m1,n1,value_e,quant)
	end subroutine ZBelem_MD_User


end module APPLICATION_MODULE_RankBenchmark_t


PROGRAM ButterflyPACK_RankBenchmark
    use z_BPACK_DEFS
    use APPLICATION_MODULE_RankBenchmark_t
	use z_BPACK_Solve_Mul

	use z_BPACK_structure
	use z_BPACK_factor
	use z_BPACK_constr
#ifdef HAVE_OPENMP
	use omp_lib
#endif
	use z_MISC_Utilities
	use z_BPACK_constr
	use z_BPACK_utilities
    implicit none

    integer rank,ii,ii1,jj,kk,nvec
	real(kind=8),allocatable:: datain(:),location_tmp(:)
	real(kind=8) :: wavelen, ds, ppw, a, v1,v2
	integer :: ierr
	type(z_Hoption),target::option
	type(z_Hstat),target::stats
	type(z_mesh),target,allocatable::msh(:)
	type(z_kernelquant),target::ker
	type(quant_app),target::quant
	type(z_Bmatrix),target::bmat
	integer,allocatable:: groupmembers(:)
	integer nmpi, Nperdim, dims(3), inds(3)
	integer level,Maxlevel,m,n
	type(z_proctree),target::ptree
	integer,allocatable::Permutation(:)
	integer,allocatable:: Nunk_m_loc(:), Nunk_n_loc(:)
	integer,allocatable::tree(:),tree_m(:),tree_n(:)
	complex(kind=8),allocatable::rhs_glo(:,:),rhs_loc(:,:),rhs_loc_ref(:,:),x_glo(:,:),x_loc(:,:)
	integer nrhs
	type(z_matrixblock_MD) ::blocks
	character(len=1024)  :: strings,strings1
	integer flag,nargs,dim_i, Npt_src, ij, ij1
	integer,allocatable::idx_src(:), idx_1(:), idx_2(:), idxs(:), idxe(:), roundedindex(:,:),indexmapper(:,:),binsizes(:)
	complex(kind=8)::tmp
	integer:: binmax 
	class(*), pointer :: Quant_ref

	!**** nmpi and groupmembers should be provided by the user
	call MPI_Init(ierr)
	call MPI_Comm_size(MPI_Comm_World,nmpi,ierr)
	allocate(groupmembers(nmpi))
	do ii=1,nmpi
		groupmembers(ii)=(ii-1)
	enddo

	!**** create the process tree
	call z_CreatePtree(nmpi,groupmembers,MPI_Comm_World,ptree)
	deallocate(groupmembers)
	!**** initialize stats and option
	call z_InitStat(stats)
	call z_SetDefaultOptions(option)


	!**** set solver parameters
	option%ErrSol=1  ! whether or not checking the factorization accuracy
	! option%format=  HODLR! HMAT!   ! the hierarhical format
	option%near_para=0.01d0        ! admissibiltiy condition, not referenced if option%format=  HODLR
	option%verbosity=1             ! verbosity level
	option%LRlevel=0             ! 0: low-rank compression 100: butterfly compression
	option%format=HSS_MD           ! currently this is the only format supported in MD
	option%per_geo=2 ! do not generate any inadmissible block in BPACK_structuring_MD

	! geometry points available
	option%xyzsort=TM ! no reordering will be perfomed
	option%knn=0   ! neareat neighbour points per geometry point, which helps improving the compression accuracy

	quant%tst = 2
	quant%wavelen = 0.25d0/8d0
	quant%zdist = 1
	ppw=2

	nargs = iargc()
	ii=1
	do while(ii<=nargs)
		call getarg(ii,strings)
		if(trim(strings)=='-quant')then ! user-defined quantity parameters
			flag=1
			do while(flag==1)
				ii=ii+1
				if(ii<=nargs)then
					call getarg(ii,strings)
					if(strings(1:2)=='--')then
						ii=ii+1
						call getarg(ii,strings1)
						if(trim(strings)=='--tst')then
							read(strings1,*)quant%tst
						elseif(trim(strings)=='--wavelen')then
							read(strings1,*)quant%wavelen
						elseif(trim(strings)=='--ndim_FIO')then
							read(strings1,*)quant%Ndim
						elseif(trim(strings)=='--N_FIO')then
							read(strings1,*)Nperdim
						elseif(trim(strings)=='--ppw')then
							read(strings1,*)ppw
						elseif(trim(strings)=='--zdist')then
							read(strings1,*)quant%zdist
						else
							if(ptree%MyID==Main_ID)write(*,*)'ignoring unknown quant: ', trim(strings)
						endif
					else
						flag=0
					endif
				else
					flag=0
				endif
			enddo
		else if(trim(strings)=='-option')then ! options of ButterflyPACK
			call z_ReadOption(option,ptree,ii)
		else
			if(ptree%MyID==Main_ID)write(*,*)'ignoring unknown argument: ',trim(strings)
			ii=ii+1
		endif
	enddo


	call z_PrintOptions(option,ptree)



!******************************************************************************!
! Read a full non-square matrix and do a BF compression



    ds = quant%wavelen/ppw
    if(quant%tst==1)then ! two colinear plate
	  quant%Ndim = 2
      Nperdim = NINT(1d0/ds)
	  allocate(quant%Nunk_m(quant%Ndim))
	  allocate(quant%Nunk_n(quant%Ndim))
      quant%Nunk_m = Nperdim
      quant%Nunk_n = Nperdim
	  allocate(quant%locations_m(quant%Ndim,Nperdim))
	  allocate(quant%locations_n(quant%Ndim,Nperdim))
	  do m=1,Nperdim
		quant%locations_m(1,m)=m*ds+1 + quant%zdist
		quant%locations_m(2,m)=m*ds
	  enddo
	  do n=1,Nperdim
		quant%locations_n(1,n)=n*ds
		quant%locations_n(2,n)=n*ds
	  enddo

    elseif(quant%tst==2)then ! two parallel plate
	  quant%Ndim = 2
      Nperdim = NINT(1d0/ds)
	  allocate(quant%Nunk_m(quant%Ndim))
	  allocate(quant%Nunk_n(quant%Ndim))
      quant%Nunk_m = Nperdim
      quant%Nunk_n = Nperdim
	  allocate(quant%locations_m(quant%Ndim,Nperdim))
	  allocate(quant%locations_n(quant%Ndim,Nperdim))
	  dims = Nperdim
	  do m=1,Nperdim
		quant%locations_m(1,m)=m*ds
		quant%locations_m(2,m)=m*ds
	  enddo
	  do n=1,Nperdim
		quant%locations_n(1,n)=n*ds
		quant%locations_n(2,n)=n*ds
	  enddo

	elseif(quant%tst==3)then ! two 3D cubes

	  quant%Ndim = 3
      Nperdim = NINT(1d0/ds)
	  allocate(quant%Nunk_m(quant%Ndim))
	  allocate(quant%Nunk_n(quant%Ndim))
      quant%Nunk_m = Nperdim
      quant%Nunk_n = Nperdim
	  allocate(quant%locations_m(quant%Ndim,Nperdim))
	  allocate(quant%locations_n(quant%Ndim,Nperdim))
	  do m=1,Nperdim
		quant%locations_m(1,m)=m*ds
		quant%locations_m(2,m)=m*ds
		quant%locations_m(3,m)=m*ds
	  enddo
	  do n=1,Nperdim
		quant%locations_n(1,n)=n*ds+1 + quant%zdist
		quant%locations_n(2,n)=n*ds
		quant%locations_n(3,n)=n*ds
	  enddo

	elseif(quant%tst==4)then ! DFT
	  allocate(quant%Nunk_m(quant%Ndim))
	  allocate(quant%Nunk_n(quant%Ndim))
      quant%Nunk_m = Nperdim
      quant%Nunk_n = Nperdim
	  allocate(quant%locations_m(quant%Ndim,Nperdim))
	  allocate(quant%locations_n(quant%Ndim,Nperdim))
	  do m=1,Nperdim
		quant%locations_m(:,m)=m-1
	  enddo
	  do n=1,Nperdim
		quant%locations_n(:,n)=dble(n-1)/Nperdim
	  enddo
	elseif(quant%tst==5)then ! 2D Radon transform for elipse integral from "Approximate inversion of discrete Fourier integral operators" and "Fast Computation of Fourier Integral Operators"
	  quant%Ndim = 2
	  allocate(quant%Nunk_m(quant%Ndim))
	  allocate(quant%Nunk_n(quant%Ndim))
      quant%Nunk_m = Nperdim
      quant%Nunk_n = Nperdim
	  allocate(quant%locations_m(quant%Ndim,Nperdim))
	  allocate(quant%locations_n(quant%Ndim,Nperdim))
	  do m=1,Nperdim
		quant%locations_m(:,m)=dble(m-1)/Nperdim
	  enddo
	  do n=1,Nperdim
		quant%locations_n(:,n)= (n-1)-Nperdim/2
	  enddo
	elseif(quant%tst==6)then ! 3D Radon transform for a plane interal generalized from "A fast butterfly algorithm for generalized Radon transforms"
	  quant%Ndim = 3
	  allocate(quant%Nunk_m(quant%Ndim))
	  allocate(quant%Nunk_n(quant%Ndim))
      quant%Nunk_m = Nperdim
      quant%Nunk_n = Nperdim
	  allocate(quant%locations_m(quant%Ndim,Nperdim))
	  allocate(quant%locations_n(quant%Ndim,Nperdim))
	  do m=1,Nperdim
		quant%locations_m(:,m)=dble(m-1)/Nperdim+1d0/Nperdim/2d0
	  enddo
	  do n=1,Nperdim
		quant%locations_n(:,n)=dble(n-1)/Nperdim
	  enddo
	elseif(quant%tst==7)then ! 2D Radon transform for a line integral generalized from "A fast butterfly algorithm for generalized Radon transforms"
	  quant%Ndim = 2
	  allocate(quant%Nunk_m(quant%Ndim))
	  allocate(quant%Nunk_n(quant%Ndim))
      quant%Nunk_m = Nperdim
      quant%Nunk_n = Nperdim
	  allocate(quant%locations_m(quant%Ndim,Nperdim))
	  allocate(quant%locations_n(quant%Ndim,Nperdim))
	  do m=1,Nperdim
		quant%locations_m(:,m)=dble(m-1)/Nperdim+1d0/Nperdim/2d0
	  enddo
	  do n=1,Nperdim
		quant%locations_n(:,n)=dble(n-1)/Nperdim
	  enddo
	elseif(quant%tst==8)then ! 2D Radon transform for hyperbolic integral in "A fast butterfly algorithm for generalized Radon transforms"
	  quant%Ndim = 2
	  allocate(quant%Nunk_m(quant%Ndim))
	  allocate(quant%Nunk_n(quant%Ndim))
      quant%Nunk_m = Nperdim
      quant%Nunk_n = Nperdim
	  allocate(quant%locations_m(quant%Ndim,Nperdim))
	  allocate(quant%locations_n(quant%Ndim,Nperdim))
	  do m=1,Nperdim
		quant%locations_m(:,m)=dble(m-1)/Nperdim+1d0/Nperdim/2d0
	  enddo
	  do n=1,Nperdim
		quant%locations_n(:,n)=dble(n-1)/Nperdim
	  enddo
	elseif(quant%tst==9)then ! 3D Radon transform for sphere integral from "A Fast Butterfly Algorithm for the Computation of Fourier Integral Operators"
	  quant%Ndim = 3
	  allocate(quant%Nunk_m(quant%Ndim))
	  allocate(quant%Nunk_n(quant%Ndim))
      quant%Nunk_m = Nperdim
      quant%Nunk_n = Nperdim
	  allocate(quant%locations_m(quant%Ndim,Nperdim))
	  allocate(quant%locations_n(quant%Ndim,Nperdim))
	  do m=1,Nperdim
		quant%locations_m(:,m)= dble(m-1)/Nperdim
	  enddo
	  do n=1,Nperdim
		quant%locations_n(:,n)= (n-1)-Nperdim/2 !dble(n-1)/Nperdim
	  enddo
	elseif(quant%tst==10)then ! NUFFT
	  allocate(quant%Nunk_m(quant%Ndim))
	  allocate(quant%Nunk_n(quant%Ndim))
      quant%Nunk_m = Nperdim
      quant%Nunk_n = Nperdim
	  allocate(quant%locations_m(quant%Ndim,Nperdim))
	  allocate(quant%locations_n(quant%Ndim,Nperdim))
	  allocate(roundedindex(Nperdim,2))
	  allocate(location_tmp(Nperdim))
	  
	  do dim_i=1,quant%Ndim
		do m=1,Nperdim
			call random_number(a)
			! call MPI_Bcast(a, 1, MPI_DOUBLE_PRECISION, Main_ID, ptree%Comm, ierr)
			quant%locations_m(dim_i,m)=z_floor_safe(Nperdim*min(a,0.99999999999d0)) !! z_floor_safe makes the rank smaller when xyzsort=0, but gives large compression error
			! quant%locations_m(dim_i,m)=Nperdim*min(a,0.99999999999d0)
			! quant%locations_m(dim_i,m)=(m*(1-0.001*a)-1)
			! quant%locations_m(dim_i,m)=m-1 
		enddo
		do n=1,Nperdim
			call random_number(a)
			! call MPI_Bcast(a, 1, MPI_DOUBLE_PRECISION, Main_ID, ptree%Comm, ierr)
			! quant%locations_n(dim_i,n)=z_floor_safe(Nperdim*min(a,0.99999999999d0))/dble(Nperdim)
			! quant%locations_n(dim_i,n)=(n*(1-0.001*a)-1)/Nperdim
			quant%locations_n(dim_i,n)=dble(n-1)/Nperdim 
		enddo
	  enddo	  

	  ! The following will take no effect if option%xyzsort\=0 	
	  do dim_i=1,quant%Ndim
		do m=1,Nperdim
		roundedindex(m,1) = z_bit_reverse(z_floor_safe(quant%locations_m(dim_i,m)/(1))+1,INT((log(dble(Nperdim)) / log(2d0))))
		roundedindex(m,2) = m
		enddo
		call z_PIKSRT_INT_Multi(Nperdim,2,roundedindex)
		location_tmp = quant%locations_m(dim_i,:)
		quant%locations_m(dim_i,:) = location_tmp(roundedindex(:,2))

		do n=1,Nperdim
		roundedindex(n,1) = z_bit_reverse(z_floor_safe(quant%locations_n(dim_i,n)/(1d0/Nperdim))+1,INT((log(dble(Nperdim)) / log(2d0))))
		roundedindex(n,2) = n
		enddo
		call z_PIKSRT_INT_Multi(Nperdim,2,roundedindex)
		location_tmp = quant%locations_n(dim_i,:)
		quant%locations_n(dim_i,:) = location_tmp(roundedindex(:,2))

	  enddo
	  call MPI_Bcast(quant%locations_m, quant%Ndim*Nperdim, MPI_DOUBLE_PRECISION, Main_ID, ptree%Comm, ierr)
	  call MPI_Bcast(quant%locations_n, quant%Ndim*Nperdim, MPI_DOUBLE_PRECISION, Main_ID, ptree%Comm, ierr)
	  

	  deallocate(roundedindex)
	  deallocate(location_tmp)
	endif

	allocate(Nunk_m_loc(quant%Ndim))
	allocate(Nunk_n_loc(quant%Ndim))
	allocate(msh(quant%Ndim))

	if(ptree%MyID==Main_ID)then
	write (*,*) ''
	write (*,*) 'RankBenchmark(Tensor) computing'
	write (*,*) 'Tensor size:', quant%Nunk_m, quant%Nunk_n
	write (*,*) ''
	endif
	!***********************************************************************

	!**** register the user-defined function and type in ker
	ker%QuantApp => quant
	ker%FuncZmn_MD => ZBelem_MD_User

	allocate(quant%Permutation_m(maxval(quant%Nunk_m),quant%Ndim))
	allocate(quant%Permutation_n(maxval(quant%Nunk_n),quant%Ndim))
	call z_BF_MD_Construct_Init(quant%Ndim, quant%Nunk_m, quant%Nunk_n, Nunk_m_loc, Nunk_n_loc, quant%Permutation_m, quant%Permutation_n, blocks, option, stats, msh, ker, ptree, Coordinates_m=quant%locations_m,Coordinates_n=quant%locations_n)
	call MPI_Bcast(quant%Permutation_m,maxval(quant%Nunk_m)*quant%Ndim,MPI_integer,0,ptree%comm,ierr)
	call MPI_Bcast(quant%Permutation_n,maxval(quant%Nunk_n)*quant%Ndim,MPI_integer,0,ptree%comm,ierr)

	call z_BF_MD_Construct_Element_Compute(quant%Ndim, blocks, option, stats, msh, ker, ptree)


	nvec=1
	allocate(x_loc(product(Nunk_n_loc),nvec))
	x_loc=0

	Npt_src = min(10,product(quant%Nunk_n))
	allocate(idx_src(Npt_src))
	do ij=1,Npt_src
		call random_number(a)
		idx_src(ij) = max(z_floor_safe(product(quant%Nunk_n)*a), 1)
	enddo
	call MPI_Bcast(idx_src, Npt_src, MPI_INTEGER, Main_ID, ptree%Comm, ierr)
	allocate(idx_1(quant%Ndim))
	allocate(idx_2(quant%Ndim))
	allocate(idxs(quant%Ndim))
	allocate(idxe(quant%Ndim))

	idxs = blocks%N_p(ptree%MyID - ptree%pgrp(1)%head + 1, 1, :)
	idxe = idxs + Nunk_n_loc -1
	do ij=1,Npt_src
		call z_SingleIndexToMultiIndex(quant%Ndim,quant%Nunk_n, idx_src(ij), idx_1)
		if(ALL(idx_1>=idxs) .and. ALL(idx_1<=idxe))then
			idx_1 = idx_1 - idxs + 1
			call z_MultiIndexToSingleIndex(quant%Ndim,Nunk_n_loc, ij1, idx_1)
			x_loc(ij1,1) = x_loc(ij1,1) + 1
		endif
	enddo

	allocate(rhs_loc(product(Nunk_m_loc),nvec))
	rhs_loc=0
	call z_BF_MD_block_mvp('N', x_loc, Nunk_n_loc, rhs_loc, Nunk_m_loc, nvec, blocks, quant%Ndim, ptree, stats, msh, option)

	idxs = blocks%M_p(ptree%MyID - ptree%pgrp(1)%head + 1, 1, :)
	allocate(rhs_loc_ref(product(Nunk_m_loc),nvec))
	rhs_loc_ref=0
	Quant_ref =>quant

#ifdef HAVE_OPENMP
	!$omp parallel do default(shared) private(ii,idx_1,ii1,ij,idx_2,tmp)
#endif
	do ii=1, product(Nunk_m_loc)
		call z_SingleIndexToMultiIndex(quant%Ndim,Nunk_m_loc, ii, idx_1)
		idx_1 = idx_1 + idxs - 1
		call z_MultiIndexToSingleIndex(quant%Ndim,quant%Nunk_m, ii1, idx_1)
		do ij=1,Npt_src
			call z_SingleIndexToMultiIndex(quant%Ndim,quant%Nunk_n, idx_src(ij), idx_2)
			call ZBelem_MD_User(quant%Ndim, idx_1, -idx_2,tmp,Quant_ref)
			rhs_loc_ref(ii,1) = rhs_loc_ref(ii,1) + tmp
		enddo
	enddo
#ifdef HAVE_OPENMP
	!$omp end parallel do
#endif

	rhs_loc = rhs_loc - rhs_loc_ref
	v1 =(z_fnorm(rhs_loc,product(Nunk_m_loc),nvec))**2d0
	v2 =(z_fnorm(rhs_loc_ref,product(Nunk_m_loc),nvec))**2d0
	call MPI_ALLREDUCE(MPI_IN_PLACE, v1, 1, MPI_DOUBLE_PRECISION, MPI_SUM, ptree%Comm, ierr)
	call MPI_ALLREDUCE(MPI_IN_PLACE, v2, 1, MPI_DOUBLE_PRECISION, MPI_SUM, ptree%Comm, ierr)
	if(ptree%MyID==Main_ID)then
		write(*,*)'multiplication (contraction) error: ', sqrt(v1/v2)
	endif

	deallocate(x_loc)
	deallocate(rhs_loc)
	deallocate(rhs_loc_ref)
	deallocate(idx_1)
	deallocate(idx_2)
	deallocate(idxs)
	deallocate(idxe)
	deallocate(idx_src)
	deallocate(Nunk_m_loc)
	deallocate(Nunk_n_loc)





!******************************************************************************!

	!**** print statistics
	call z_PrintStat(stats,ptree)

	call z_BF_MD_delete(quant%Ndim, blocks, 1)
	call z_delete_proctree(ptree)
	call z_delete_Hstat(stats)
	do dim_i=1,quant%Ndim
		call z_delete_mesh(msh(dim_i))
	enddo
	deallocate(msh)
	call z_delete_kernelquant(ker)


    if(ptree%MyID==Main_ID .and. option%verbosity>=0)write(*,*) "-------------------------------program end-------------------------------------"

	call z_blacs_exit_wrp(1)
	call MPI_Finalize(ierr)

end PROGRAM ButterflyPACK_RankBenchmark



