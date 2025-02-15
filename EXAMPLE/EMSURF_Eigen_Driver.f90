! “ButterflyPACK” Copyright (c) 2018, The Regents of the University of California, through
! Lawrence Berkeley National Laboratory (subject to receipt of any required approvals from the
! U.S. Dept. of Energy). All rights reserved.

! If you have questions about your rights to use or distribute this software, please contact
! Berkeley Lab's Intellectual Property Office at  IPO@lbl.gov.

! NOTICE.  This Software was developed under funding from the U.S. Department of Energy and the
! U.S. Government consequently retains certain rights. As such, the U.S. Government has been
! granted for itself and others acting on its behalf a paid-up, nonexclusive, irrevocable
! worldwide license in the Software to reproduce, distribute copies to the public, prepare
! derivative works, and perform publicly and display publicly, and to permit other to do so.

! Developers: Yang Liu
!             (Lawrence Berkeley National Lab, Computational Research Division).

!> @file
!> @brief This is an example that uses PARPACK and ButterflyPACK to find the smallest eigen value or do characteristic mode analysis for a 3D EFIE/MFIE/CFIE system in electromagnetics.
!> @details Note that the use of the following \n
!> #define DAT 0 \n
!> #include "zButterflyPACK_config.fi" \n
!> which will macro replace subroutine, function, type names with those defined in SRC_DOUBLECOMLEX with double-complex precision

! This exmple works with double-complex precision data
PROGRAM ButterflyPACK_IE_3D
    use z_BPACK_DEFS
	use EMSURF_MODULE

	use z_BPACK_structure
	use z_BPACK_factor
	use z_BPACK_constr
	use z_BPACK_Solve_Mul
#ifdef HAVE_OPENMP
	use omp_lib
#endif
	use z_MISC_Utilities
	use z_BPACK_utilities
    implicit none

	! include "mkl_vml.fi"

    real(kind=8) para
    real(kind=8) tolerance
    integer Primary_block, nn, mm,kk,mn,rank,ii,jj,nn1
    integer i,j,k, threads_num
	integer seed_myid(50)
	integer times(8)
	real(kind=8) t1,t2,x,y,z,r,norm1,normi,maxnorm
	complex(kind=8),allocatable:: matU(:,:),matV(:,:),matZ(:,:),LL(:,:),RR(:,:),matZ1(:,:)

	character(len=:),allocatable  :: string
	character(len=1024)  :: strings,strings1
	character(len=6)  :: info_env
	integer :: length,edge
	integer :: ierr
	integer*8 oldmode,newmode
	type(z_Hoption)::option_sh,option_A,option_B
	type(z_Hstat)::stats_sh,stats_A,stats_B
	type(z_mesh)::msh_sh,msh_A,msh_B
	type(z_Bmatrix)::bmat_sh,bmat_A,bmat_B
	type(z_kernelquant)::ker_sh,ker_A,ker_B
	type(quant_EMSURF),target::quant
	type(z_proctree)::ptree_sh,ptree_A,ptree_B
	integer,allocatable:: groupmembers(:)
	integer nmpi
	real(kind=8),allocatable::xyz(:,:)
	integer,allocatable::Permutation(:)
	integer Nunk_loc

	integer maxn, maxnev, maxncv, ldv
	integer iparam(11), ipntr(14)
    logical,allocatable:: select(:)
    complex(kind=8),allocatable:: ax(:), mx(:), d(:), v(:,:), workd(:), workev(:), resid(:), workl(:), eigval(:), eigvec(:,:)
    real(kind=8),allocatable:: rwork(:), rd(:,:)

    character bmattype
	character(len=10) which
    integer ido, n, nx, nev, ncv, lworkl, info, nconv, maxitr, ishfts, mode
    complex(kind=8) sigma
    real(kind=8) tol, retval(2)
    real(kind=8) dtheta,theta,phi,rcs
	complex(kind=8) ctemp_loc,ctemp_1,ctemp
    logical rvec
	real(kind=8),external :: pdznorm2, dlapy2
	character(len=1024)  :: substring,substring1
	integer v_major,v_minor,v_bugfix

	integer nargs,flag
	integer parent

	! nmpi and groupmembers should be provided by the user
	call MPI_Init(ierr)
	call MPI_COMM_GET_PARENT(parent, ierr) ! YL: this is needed if this function is spawned by a master process
	call MPI_Comm_size(MPI_Comm_World,nmpi,ierr)
	allocate(groupmembers(nmpi))
	do ii=1,nmpi
		groupmembers(ii)=(ii-1)
	enddo

	call z_CreatePtree(nmpi,groupmembers,MPI_Comm_World,ptree_A)
	deallocate(groupmembers)


	if(ptree_A%MyID==Main_ID)then
    write(*,*) "-------------------------------Program Start----------------------------------"
    write(*,*) "ButterflyPACK_IE_3D"
	call z_BPACK_GetVersionNumber(v_major,v_minor,v_bugfix)
	write(*,'(A23,I1,A1,I1,A1,I1,A1)') " ButterflyPACK Version:",v_major,".",v_minor,".",v_bugfix
    write(*,*) "   "
	endif

	!**** initialize stats and option
	call z_InitStat(stats_sh)
	call z_SetDefaultOptions(option_A)


	!**** intialize the user-defined derived type quant
	! compute the quadrature rules
    quant%integral_points=6
    allocate (quant%ng1(quant%integral_points), quant%ng2(quant%integral_points), quant%ng3(quant%integral_points), quant%gauss_w(quant%integral_points))
    call gauss_points(quant)

    !*************************input******************************
	quant%DATA_DIR='../EXAMPLE/EM3D_DATA/sphere_2300'

	quant%mesh_normal=1
	quant%scaling=1d0
	quant%wavelength=2.0
	quant%freq=1/quant%wavelength/sqrt(BPACK_mu0*BPACK_eps0)
	quant%RCS_static=2
    quant%RCS_Nsample=1000
	quant%CFIE_alpha=1

	!**** default parameters for the eigen solvers
	quant%CMmode=0
	quant%SI=0
	quant%shift=(0d0, 0d0)
	quant%nev=1
	quant%tol_eig=1d-13
	quant%which='LM'


	option_A%ErrSol=1
	option_A%format=  HMAT!  HODLR !
	option_A%near_para=2.01d0
	option_A%verbosity=1
	option_A%ILU=0
	option_A%forwardN15flag=0
	option_A%LRlevel=100
	option_A%tol_itersol=1d-5
	option_A%sample_para=4d0

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
						if(trim(strings)=='--data_dir')then
							quant%data_dir=trim(strings1)
						else if	(trim(strings)=='--wavelength')then
							read(strings1,*)quant%wavelength
							quant%freq=1/quant%wavelength/sqrt(BPACK_mu0*BPACK_eps0)
						else if (trim(strings)=='--freq')then
							read(strings1,*)quant%freq
							quant%wavelength=1/quant%freq/sqrt(BPACK_mu0*BPACK_eps0)
						else if (trim(strings)=='--scaling')then
							read(strings1,*)quant%scaling
						else if	(trim(strings)=='--cmmode')then
							read(strings1,*)quant%CMmode
						else if	(trim(strings)=='--si')then
							read(strings1,*)quant%SI
						else if	(trim(strings)=='--nev')then
							read(strings1,*)quant%nev
						else if	(trim(strings)=='--tol_eig')then
							read(strings1,*)quant%tol_eig
						else if	(trim(strings)=='--which')then
							quant%which=trim(strings1)
						else
							if(ptree_A%MyID==Main_ID)write(*,*)'ignoring unknown quant: ', trim(strings)
						endif
					else
						flag=0
					endif
				else
					flag=0
				endif
			enddo
		else if(trim(strings)=='-option')then ! options of ButterflyPACK
			call z_ReadOption(option_A,ptree_A,ii)
		else
			if(ptree_A%MyID==Main_ID)write(*,*)'ignoring unknown argument: ',trim(strings)
			ii=ii+1
		endif
	enddo

	call z_PrintOptions(option_A,ptree_A)


    quant%wavenum=2*BPACK_pi/quant%wavelength
	! option_A%touch_para = 3* quant%minedgelength

   !***********************************************************************
	if(ptree_A%MyID==Main_ID)then
   write (*,*) ''
   write (*,*) 'EFIE computing'
   write (*,*) 'frequency:',quant%freq
   write (*,*) 'wavelength:',quant%wavelength
   write (*,*) ''
	endif
   !***********************************************************************


	!***********************************************************************
	!**** construct compressed A
	!**** geometry generalization and discretization
	call geo_modeling_SURF(quant,ptree_A%Comm,quant%DATA_DIR)
	!**** register the user-defined function and type in ker
	ker_A%QuantApp => quant
	ker_A%FuncZmn => Zelem_EMSURF
	!**** initialization of the construction phase
	t1 = MPI_Wtime()
	allocate(xyz(3,quant%Nunk))
	do ii=1, quant%Nunk
		xyz(:,ii) = quant%xyz(:,quant%maxnode+ii)
	enddo
    allocate(Permutation(quant%Nunk))
	call z_BPACK_construction_Init(quant%Nunk,Permutation,Nunk_loc,bmat_A,option_A,stats_A,msh_A,ker_A,ptree_A,Coordinates=xyz)
	deallocate(Permutation) ! caller can use this permutation vector if needed
	deallocate(xyz)
	t2 = MPI_Wtime()
	!**** computation of the construction phase
    call z_BPACK_construction_Element(bmat_A,option_A,stats_A,msh_A,ker_A,ptree_A)
	!**** print statistics
	call z_PrintStat(stats_A,ptree_A)


	!***********************************************************************
	!**** construct compressed A - sigma I or  A - sigma real(A)
	if(quant%SI==1)then
		call z_CopyOptions(option_A,option_sh)
		!**** register the user-defined function and type in ker
		ker_sh%QuantApp => quant
		ker_sh%FuncZmn => Zelem_EMSURF_Shifted
		!**** initialize stats_sh and option
		call z_InitStat(stats_sh)
		!**** create the process tree, can use larger number of mpis if needed
		allocate(groupmembers(nmpi))
		do ii=1,nmpi
			groupmembers(ii)=(ii-1)
		enddo
		call z_CreatePtree(nmpi,groupmembers,MPI_Comm_World,ptree_sh)
		deallocate(groupmembers)
		!**** initialization of the construction phase
		t1 = MPI_Wtime()
		allocate(xyz(3,quant%Nunk))
		do ii=1, quant%Nunk
			xyz(:,ii) = quant%xyz(:,quant%maxnode+ii)
		enddo
		allocate(Permutation(quant%Nunk))
		call z_BPACK_construction_Init(quant%Nunk,Permutation,Nunk_loc,bmat_sh,option_sh,stats_sh,msh_sh,ker_sh,ptree_sh,Coordinates=xyz)
		deallocate(Permutation) ! caller can use this permutation vector if needed
		deallocate(xyz)
		t2 = MPI_Wtime()
		!**** computation of the construction phase
		call z_BPACK_construction_Element(bmat_sh,option_sh,stats_sh,msh_sh,ker_sh,ptree_sh)
		!**** factorization phase
		call z_BPACK_Factorization(bmat_sh,option_sh,stats_sh,ptree_sh,msh_sh)
		! !**** solve phase
		! call EM_solve_SURF(bmat_sh,option_sh,msh_sh,quant,ptree_sh,stats_sh)
		!**** print statistics
		call z_PrintStat(stats_sh,ptree_sh)
	endif


	!***********************************************************************
	!**** construct compressed real(A)
	if(quant%CMmode==1)then ! solve the characteristic mode
		call z_CopyOptions(option_A,option_B)
		!**** register the user-defined function and type in ker
		ker_B%QuantApp => quant
		ker_B%FuncZmn => Zelem_EMSURF_Real
		!**** initialize stats_sh and option
		call z_InitStat(stats_B)
		!**** create the process tree, can use larger number of mpis if needed
		allocate(groupmembers(nmpi))
		do ii=1,nmpi
			groupmembers(ii)=(ii-1)
		enddo
		call z_CreatePtree(nmpi,groupmembers,MPI_Comm_World,ptree_B)
		deallocate(groupmembers)
		!**** initialization of the construction phase
		t1 = MPI_Wtime()
		allocate(xyz(3,quant%Nunk))
		do ii=1, quant%Nunk
			xyz(:,ii) = quant%xyz(:,quant%maxnode+ii)
		enddo
		allocate(Permutation(quant%Nunk))
		call z_BPACK_construction_Init(quant%Nunk,Permutation,Nunk_loc,bmat_B,option_B,stats_B,msh_B,ker_B,ptree_B,Coordinates=xyz)
		deallocate(Permutation) ! caller can use this permutation vector if needed
		deallocate(xyz)
		t2 = MPI_Wtime()
		!**** computation of the construction phase
		call z_BPACK_construction_Element(bmat_B,option_B,stats_B,msh_B,ker_B,ptree_B)
		!**** factorization phase
		if(quant%SI==0)then
			call z_BPACK_Factorization(bmat_B,option_B,stats_B,ptree_B,msh_B)
		endif
		!**** print statistics
		call z_PrintStat(stats_B,ptree_B)
	endif

	!***********************************************************************
	!**** eigen solver
	allocate(eigval(quant%nev))
	allocate(eigvec(Nunk_loc,quant%nev))
	call z_BPACK_Eigen(bmat_A,option_A,ptree_A, stats_A,bmat_B,option_B,ptree_B, stats_B, bmat_sh,option_sh,ptree_sh,stats_sh, quant%Nunk,Nunk_loc, quant%nev,quant%tol_eig,quant%CMmode,quant%SI,quant%shift,quant%which,nconv,eigval,eigvec)
	do ii=1,nconv
	write(substring , *) ii
	write(substring1 , *) quant%freq
	call current_node_patch_mapping('EigVec_'//trim(adjustl(substring))//'_freq_'//trim(adjustl(substring1))//'.out',eigvec(:,ii),msh_A,quant,ptree_A)

	if(quant%CMmode==1)then
		if(ptree_A%MyID==Main_ID)open (100, file='VV_bistatic_'//'EigVec_'//trim(adjustl(substring))//'_freq_'//trim(adjustl(substring1))//'.txt')
		dtheta=180./quant%RCS_Nsample
		phi=0
		do i=0, quant%RCS_Nsample
			theta=i*dtheta
			ctemp_loc=(0.,0.)
			rcs=0
#ifdef HAVE_OPENMP
			!$omp parallel do default(shared) private(edge,ctemp_1) reduction(+:ctemp_loc)
#endif
			do edge=msh_A%idxs,msh_A%idxe
				call VV_polar_SURF(theta,phi,msh_A%new2old(edge),ctemp_1,eigvec(edge-msh_A%idxs+1,ii),quant)
				ctemp_loc=ctemp_loc+ctemp_1
			enddo
#ifdef HAVE_OPENMP
			!$omp end parallel do
#endif
			call MPI_ALLREDUCE(ctemp_loc,ctemp,1,MPI_DOUBLE_COMPLEX,MPI_SUM,ptree_A%Comm,ierr)

			rcs=(abs(quant%wavenum*ctemp))**2/4/BPACK_pi
			!rcs=rcs/quant%wavelength
			rcs=10*log10(rcs)
			if(ptree_A%MyID==Main_ID)write(100,*)theta,rcs
		enddo
		if(ptree_A%MyID==Main_ID)close(100)
	endif
	enddo

	if(ptree_A%MyID==Main_ID)then
		write(*,*)'Checking 1-norm of the eigenvectors: '
	endif
	maxnorm=0
	do nn=1,quant%nev
		norm1 = z_fnorm(eigvec(:,nn:nn), Nunk_loc, 1, '1')
		normi = z_fnorm(eigvec(:,nn:nn), Nunk_loc, 1, 'I')
		call MPI_ALLREDUCE(MPI_IN_PLACE, norm1, 1, MPI_DOUBLE_PRECISION, MPI_SUM, ptree_A%Comm, ierr)
		call MPI_ALLREDUCE(MPI_IN_PLACE, normi, 1, MPI_DOUBLE_PRECISION, MPI_MAX, ptree_A%Comm, ierr)
		norm1 =norm1/normi
		if(norm1>maxnorm)then
			nn1=nn
			maxnorm = norm1
		endif
		if(ptree_A%MyID==Main_ID)then
			write(*,*)dble(eigval(nn)),aimag(eigval(nn)),norm1
		endif
	enddo

	retval(1) = abs(eigval(nn1))
	retval(2) = maxnorm


	deallocate(eigval)
	deallocate(eigvec)


	if(ptree_A%MyID==Main_ID .and. option_A%verbosity>=0)write(*,*) "-------------------------------program end-------------------------------------"

	if(quant%SI==1)then
		call z_delete_proctree(ptree_sh)
		call z_delete_Hstat(stats_sh)
		call z_delete_mesh(msh_sh)
		call z_delete_kernelquant(ker_sh)
		call z_BPACK_delete(bmat_sh)
	endif

	call z_delete_proctree(ptree_A)
	call z_delete_Hstat(stats_A)
	call z_delete_mesh(msh_A)
	call z_delete_kernelquant(ker_A)
	call z_BPACK_delete(bmat_A)

	if(quant%CMmode==1)then ! solve the characteristic mode
		call z_delete_proctree(ptree_B)
		call z_delete_Hstat(stats_B)
		call z_delete_mesh(msh_B)
		call z_delete_kernelquant(ker_B)
		call z_BPACK_delete(bmat_B)
	endif

	!**** deletion of quantities
	call delete_quant_EMSURF(quant)

	if(parent/= MPI_COMM_NULL)then
		call MPI_REDUCE(retval, MPI_BOTTOM, 2, MPI_double_precision, MPI_MAX, Main_ID, parent,ierr)
		call MPI_Comm_disconnect(parent,ierr)
	endif
	call z_blacs_exit_wrp(1)
	call MPI_Finalize(ierr)

    ! ! ! ! pause

end PROGRAM ButterflyPACK_IE_3D







