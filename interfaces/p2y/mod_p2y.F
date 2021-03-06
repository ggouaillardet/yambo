!
!        Copyright (C) 2000-2017 the YAMBO team
!              http://www.yambo-code.org
!
! Authors (see AUTHORS file for details): AM
!
! This file is distributed under the terms of the GNU
! General Public License. You can redistribute it and/or
! modify it under the terms of the GNU General Public
! License as published by the Free Software Foundation;
! either version 2, or (at your option) any later version.
!
! This program is distributed in the hope that it will
! be useful, but WITHOUT ANY WARRANTY; without even the
! implied warranty of MERCHANTABILITY or FITNESS FOR A
! PARTICULAR PURPOSE.  See the GNU General Public License
! for more details.
!
! You should have received a copy of the GNU General Public
! License along with this program; if not, write to the Free
! Software Foundation, Inc., 59 Temple Place - Suite 330,Boston,
! MA 02111-1307, USA or visit http://www.gnu.org/copyleft/gpl.txt.
!
module P2Y
 !
#if defined _P2Y_EXPORT
 use pw_export
#else 
 use qexml_module
#endif
 use pw_data
 use pars,                  ONLY : lchlen,SP, DP
 use electrons,             ONLY : levels
 use R_lattice,             ONLY : bz_samp
 use mod_com2y,             ONLY : verboseIO
 ! 
 implicit none
 !
 character(lchlen) :: index_filename
 !
 integer, public  :: pw_unit 
 integer, private :: i1,i2,ierr
 !
 ! Memory saving tools
 !
 integer, parameter       :: max_blocksize = 9
 integer                  :: blocksize(max_blocksize)
 !
contains
 !
 !---------------------------------------------------------------------*
 !    Select and open XML files                                        *
 !---------------------------------------------------------------------*
 !
 subroutine pw_init(instr,inf)
   !
   use pars,  ONLY:lchlen
   use com,   ONLY:msg
   character(*)  :: instr,inf
   !
   ! Work Space
   !
   integer           :: rhounit_ 
   character(lchlen) :: lch
   logical           :: lexist
   !
   ! index filenames
   !
#if defined _P2Y_EXPORT

   index_filename = 'index.xml'

#elif defined _P2Y_V31

   index_filename = 'data-file.xml'
   pwversion = 31 
   write(lch,'(a,i3,a)') '== PWscf v.',pwversion,' generated data =='

#elif defined _P2Y_V311

   index_filename = 'data-file.xml'
   pwversion = 311
   write(lch,'(a,i3,a)') '== PWscf v.',pwversion,' generated data =='

#elif defined _P2Y_V32

   index_filename = 'data-file.xml'
   write(lch,'(a,i3,a)') '== PWscf v.3.2 generated data =='

#elif defined _P2Y_V40 

   index_filename = 'data-file.xml'
   write(lch,'(a,i3,a)') '== PWscf v.4.x generated data =='

#elif defined _P2Y_V50 

   index_filename = 'data-file.xml'
   write(lch,'(a,i3,a)') '== PWscf v.5.0 generated data =='

#endif

   if (trim(inf).ne."p2y.in") index_filename = inf

   call msg('s','Index file set to ',trim(index_filename))
   inquire(file=trim(index_filename),exist=lexist)
   if(.not.lexist) then
     call msg('s','Index file not found! Check p2y version...')
     stop ' '
   endif
   !
   ! Open XML index files and units
   !
   pw_unit = 10
#if defined _P2Y_EXPORT
    
   call msg('s','== pw_export generated data ==')
   call pw_openindex(pw_unit,index_filename) ! open index.xml file
    
#elif defined _P2Y_V31  || defined _P2Y_V311

   call msg('s',trim(lch))
   rhounit_ = 12
   call qexml_init(pw_unit,rhounit_,.true.) ! sets unit numbers
   call qexml_openfile( index_filename, "read", .false., ierr)

#elif defined _P2Y_V32

   rhounit_ = 12
   call qexml_init(pw_unit,"./", rhounit_,.true.) ! sets unit numbers
   call qexml_openfile( index_filename, "read", .false., ierr)
    
#elif defined _P2Y_V40 || defined _P2Y_V50

   rhounit_ = 12
   call qexml_init(pw_unit) 
   call qexml_openfile( index_filename, "read", .false., ierr)
    
#endif
   !
   !  qexml_init(_,_,.true.)               : rho file is binary
   !  qexml_openfile(_,"read"/"write",_,_) : read only from existing files
   !  qexml_openfile(_,_,.false.,_)        : data-file.xml is not binary
   !
 end subroutine pw_init
 !
 !---------------------------------------------------------------------*
 !    Close the XML files                                              *
 !---------------------------------------------------------------------*
 !
 subroutine pw_close
   !
#if defined _P2Y_EXPORT

   call pw_closeindex(pw_unit) ! close index.xml file

#elif defined _P2Y_V31 || defined _P2Y_V32 || defined _P2Y_V311 || defined _P2Y_V40 || defined _P2Y_V50

   call qexml_closefile("read",ierr) ! close index.xml file

#endif
   return
 end subroutine pw_close

 !
 !---------------------------------------------------------------------*
 !    Read dimensions                                                  *
 !---------------------------------------------------------------------*
 !
 subroutine get_dimensions(en,k)
   !
   use electrons,             ONLY : default_nel, n_spin, n_sp_pol, &
&                                    n_spinor, n_spin_den, l_spin_orbit
   use R_lattice,             ONLY : ng_vec
   use D_lattice,             ONLY : input_GS_Tel, n_atomic_species
   use wave_func,             ONLY : wf_ncx 
   use com,                   ONLY : msg, error
   use LIVE_t,                ONLY : live_timing_is_on
   use units,                 ONLY : HA2KEL
   type(levels),     intent(out)  :: en     ! Energies
   type(bz_samp),    intent(out)  :: k      ! K/Q points
   !
   ! Call the version dependent routines
   !
   gamma_only_ = .false.
#if defined _P2Y_EXPORT

   call pw_dimensions(pw_unit)
    
#elif defined _P2Y_V31 || defined _P2Y_V311

   call qexml_read_bands(nbnd=nbnd_, num_k_points=num_k_points_, &
&                        nspin=n_spin_pw_, nelec=nelec_, ierr=ierr)

#elif defined _P2Y_V32

   call qexml_read_bands_info(nbnd=nbnd_, num_k_points=num_k_points_, &
&                        nspin=n_spin_pw_, nelec=nelec_, ierr=ierr)

#elif defined _P2Y_V40 || defined _P2Y_V50

   call qexml_read_bands_info(nbnd=nbnd_, num_k_points=num_k_points_, &
&                        nspin=n_spin_pw_, nelec=nelec_, ierr=ierr)

#endif

   if (ierr.ne.0) then
     live_timing_is_on=.FALSE.
     call msg('ms','Error reading data: most likely you are using an incompatible')
     call msg('s','version of p2y with your data.')
     call msg('s','Action: Compile a compatible version of p2y.')
     call errore('qexml_read_bands.','IOTK error:',ABS(ierr)) 
   endif

#if defined _P2Y_V31 || defined _P2Y_V32 || defined _P2Y_V311 || defined _P2Y_V40 || defined _P2Y_V50

   call qexml_read_symmetry(nsym=nsym_, ierr=ierr)
   if (ierr.ne.0) call errore('qexml_read_symmetry','IOTK error',ABS(ierr))
   call qexml_read_spin(lspinorb=l_spin_orbit, ierr=ierr)
   if (ierr.ne.0) call errore('qexml_read_spin','IOTK error',ABS(ierr))
   call qexml_read_planewaves(gamma_only=gamma_only_, npwx=npwx_,ngm=ngm_, ierr=ierr)
   if (ierr.ne.0) call errore('qexml_read_planewaves','IOTK error',ABS(ierr))
   call qexml_read_ions(nat=nat_, nsp=nsp_, ierr=ierr)
   if (ierr.ne.0) call errore('qexml_read_ions','IOTK error',ABS(ierr))
   !
   default_nel = nelec_
   n_atomic_species = nsp_     

#endif

   k%nibz      = num_k_points_
   en%nb       = nbnd_
   !
   ! YAMBO presently does not make use of GAMMA_ONLY option, hence
   ! the wfc's and G's must be doubled in this case.
   ! Note: the quantities in the PW files are still dimensioned ngm_ and npwx_
   !
   if(gamma_only_) then
     ng_vec      = 2*(ngm_ -1) + 1
     wf_ncx      = 2*(npwx_-1) + 1
   else
     ng_vec      = ngm_
     wf_ncx      = npwx_ 
   endif
   !
   ! Set miscellanous YAMBO data: dimensions
   !
   n_spin_den = n_spin_pw_
   select case(n_spin_pw_)
   case(1)
     n_sp_pol  = 1
     n_spinor  = 1
     n_spin    = 1
   case(2)
     n_sp_pol  = 2
     n_spinor  = 1
     n_spin    = 2
   case(4)
     n_sp_pol  = 1
     n_spinor  = 2
     n_spin    = 2
   end select
   !
   input_GS_Tel = 0.d0
   !
#if defined _P2Y_V40 || defined _P2Y_V50
   !
   call qexml_read_occ(lgauss=lgauss_,ngauss=ngauss_,degauss=degauss_,&
&                               degauss_units=degauss_units_, ierr=ierr)
   if (ierr.ne.0) call errore('qexml_read_occ','IOTK error',ABS(ierr))  
   !
   if (lgauss_) input_GS_Tel=300._SP/HA2KEL
   !
#endif
   !
   return
 end subroutine get_dimensions
 !
 !---------------------------------------------------------------------*
 !    Read atomic data                                                 *
 !---------------------------------------------------------------------*
 !
 subroutine get_atoms
   use D_lattice,   ONLY:n_atoms_species_max,n_atomic_species,n_atoms_species, &
&                        atom_pos, Z_species,atomic_number
   !
   ! Work Space
   !
   real(DP)                       :: tau_units
   real(SP)                       :: z
   integer                        :: i1,i2,u

   allocate( ityp_(nat_) )
   allocate( tau_(3,nat_) )  

#if defined _P2Y_EXPORT

   allocate(atom_type_ ( nat_), stat=ierr)
   allocate(species_type_ ( nat_), stat=ierr) 

   call pw_atoms(pw_unit)

   n_atomic_species = nsp_     ! n_atom_species only read here
   allocate( atm_(n_atomic_species)) 
   atm_(1:n_atomic_species) = species_type_(1:n_atomic_species)
   do i1=1, nat_
     ityp_(i1) = -1
     do i2=1,n_atomic_species
       if(trim(atom_type_(i1))==trim(atm_(i2))) then
         ityp_(i1) = i2
       endif
     enddo
   enddo
   tau_units = alat_

   deallocate(atom_type_,species_type_)

#elif defined _P2Y_V31 || defined _P2Y_V32 || defined _P2Y_V311 || defined _P2Y_V40 || defined _P2Y_V50

   tau_units = 1.0_DP
   allocate( atm_(n_atomic_species))
   allocate( psfile (n_atomic_species))
   allocate( nmesh (n_atomic_species), nbeta (n_atomic_species))
   call qexml_read_ions( atm=atm_, ityp=ityp_, psfile=psfile, tau=tau_, ierr=ierr)
   ! Check USPP/NC pseudopotential
   do i1 =1,n_atomic_species
     call read_pseudo_header(u,z,psfile(i1),nmesh(i1),nbeta(i1))
   enddo

#endif

   allocate(n_atoms_species(n_atomic_species))
   n_atoms_species(:)=0
   do i1 = 1, nat_
     n_atoms_species( ityp_(i1) ) = n_atoms_species( ityp_(i1) ) +1
   enddo
   n_atoms_species_max = maxval(n_atoms_species)
   allocate(atom_pos(3,n_atoms_species_max,n_atomic_species))
   n_atoms_species(:)=0
   do i1 = 1, nat_
     n_atoms_species( ityp_(i1) ) = n_atoms_species( ityp_(i1) ) +1
     atom_pos(:, n_atoms_species( ityp_(i1) ) , ityp_(i1) ) = tau_(:,i1)*tau_units
   enddo

   allocate(Z_species(n_atomic_species))
   do i1 = 1, n_atomic_species
     Z_species(i1) = atomic_number(atm_(i1))
   enddo

   return
 end subroutine get_atoms
 !
 !---------------------------------------------------------------------*
 !    Read cell data                                                   *
 !---------------------------------------------------------------------*
 !
 subroutine get_cell
   use pars,                  only : pi
   use R_lattice,             ONLY : bz_samp, ng_vec, b
   use D_lattice,             ONLY : DL_vol, a, alat,lattice
   use mod_com2y,             ONLY : alat_mult_factor
   use vec_operate,           ONLY : cross_product
   real(SP) :: cp(3)
    
#if defined _P2Y_EXPORT

   call pw_cell(pw_unit)

#elif defined _P2Y_V31 || defined _P2Y_V32 || defined _P2Y_V311 || defined _P2Y_V40 || defined _P2Y_V50

   call qexml_read_cell(alat=alat_, a1=a1_, a2=a2_, a3=a3_,ierr=ierr)
   if (ierr.ne.0) call errore('qexml_read_cell','IOTK error',ABS(ierr))
    
#endif

   a(1,:) = a1_(:) ! assumes always atomic units
   a(2,:) = a2_(:)
   a(3,:) = a3_(:)
   !
   ! Set related YAMBO data: cell
   !
   alat(1) = maxval(abs(a(1,:)))*alat_mult_factor
   alat(2) = maxval(abs(a(2,:)))*alat_mult_factor
   alat(3) = maxval(abs(a(3,:)))*alat_mult_factor
   call crystal_lattice()
   cp = cross_product(a(2,:),a(3,:))
   do i1=1,3
     DL_vol= DL_vol+a(1,i1)*cp(i1)
   enddo
   b(1,:)=cross_product(a(2,:),a(3,:))*2.0_SP*pi/DL_vol
   b(2,:)=cross_product(a(3,:),a(1,:))*2.0_SP*pi/DL_vol
   b(3,:)=cross_product(a(1,:),a(2,:))*2.0_SP*pi/DL_vol

   return
 end subroutine get_cell
 !
 !---------------------------------------------------------------------*
 !    Read symmetries                                                  *
 !---------------------------------------------------------------------*
 !
 subroutine get_symmetries
   use mod_com2y,  ONLY : symmetries_check_and_load
   use com,        ONLY : warning,error
   use vec_operate,ONLY : v_is_zero

   real(DP) :: trasl_(3,48)

   trasl_=0._SP

#if defined _P2Y_EXPORT

   call pw_symmetry(pw_unit)
   trevsym_=.true.
   t_rev_=0

#elif defined _P2Y_V31 || defined _P2Y_V32 || defined _P2Y_V311 || defined _P2Y_V40 || defined _P2Y_V50

   call qexml_read_symmetry(invsym=invsym_, trevsym=trevsym_, trasl=trasl_(:,1:nsym_), &
&                                         s=isym_(:,:,1:nsym_), t_rev=t_rev_ , ierr=ierr)
   if (ierr.ne.0) call errore('qexml_read_symmetry','IOTK error',ABS(ierr))

#endif
   !
   do i1=1,nsym_
     if (.not.v_is_zero(real(trasl_(:,i1),SP)) ) then 
       call error(' Non-symmorphic symmetry operations are not supported! Use force_symmorphic=.true. in PWSCF')
     endif
   enddo
   !
   ! Note that invsym_ is well defined here, could be used for checks.
   do i1 = 1,nsym_
     isym_(:,:,i1) = transpose(isym_(:,:,i1))
   enddo
   call symmetries_check_and_load(isym_(:,:,1:nsym_),nsym_,trevsym=trevsym_, t_rev=t_rev_)
   !
 end subroutine get_symmetries
 !
 !---------------------------------------------------------------------*
 !    Read K-point data                                                *
 !---------------------------------------------------------------------*
 !
 subroutine get_k_points(k)
   !
   use R_lattice,   ONLY:bz_samp
   use D_lattice,   ONLY:alat
   use vec_operate, ONLY:v_is_zero
   use com,         ONLY:warning
   type(bz_samp) :: k
   !
   allocate(xk_(3, k%nibz))
#if defined _P2Y_EXPORT

   call pw_kpoints(pw_unit)

#elif defined _P2Y_V31 || defined _P2Y_V32 || defined _P2Y_V311 || defined _P2Y_V40 || defined _P2Y_V50

   call qexml_read_bz(xk=xk_, ierr=ierr)
   if (ierr.ne.0) call errore('qexml_read_bands','IOTK error',ABS(ierr))

#endif
   !
   ! PW k in units of [cart, tpiba] -> units of [cart, 2*pi/alat(:)]
   ! PW cart tpiba/cart au/cart alat/RLU units
   !
   allocate(k%pt(k%nibz,3))
   do i1=1,k%nibz
     k%pt(i1,:)=xk_(:,i1) * alat(:)/alat_ 
   enddo
!  deallocate(xk_)

#if defined _P2Y_EXPORT
 
   if(k%nibz==1.and.v_is_zero(k%pt(1,:))) then
     call warning(' GAMMA_ONLY calculations are not supported in pw_export. ')
   endif
   
#endif

   !
   return
 end subroutine get_k_points
 !
 !---------------------------------------------------------------------*
 !    Read miscellaneous data                                          *
 !---------------------------------------------------------------------*
 !
 subroutine get_more
   use electrons,             ONLY : default_nel
   !
#if defined _P2Y_EXPORT
   call pw_other(pw_unit)
   default_nel = nelec_ 
#endif
   !
   return
 end subroutine get_more
 !
 !---------------------------------------------------------------------*
 !    Read reciprocal lattice vectors                                  *
 !---------------------------------------------------------------------*
 !
 subroutine get_R_vectors
   use pars,        only : pi
   use R_lattice,   ONLY:b, ng_vec, g_vec
   use D_lattice,   ONLY:alat
   !
   allocate(g_vec(ng_vec,3)) ! The YAMBO array

#if defined _P2Y_EXPORT

   allocate(igv_(3,ng_vec))    
   call pw_gvectors(pw_unit)

#elif defined _P2Y_V31 || defined _P2Y_V32 || defined _P2Y_V311 || defined _P2Y_V40 || defined _P2Y_V50

   allocate(igv_(3,ngm_))    ! The PWscf array (ngm = ng_vec if not gamma_only)
   call qexml_read_planewaves(ecutwfc=ecutwfc_,igv=igv_, ierr=ierr)
   if (ierr.ne.0) call errore('qexml_read_planewaves','IOTK error',ABS(ierr))

#endif
   !
   ! PW integer units of b1/b2/b3    -> 2pi/alat(:) units, cartesian, real
   ! b(:,:) is in a.u.
   !
   if(gamma_only_) then
     !
     g_vec(1,:)=matmul(transpose(b),igv_(:,1))*alat(:)/2.0_SP/pi
     do i1 = 2,ngm_
        g_vec(2*i1-2,:)  = matmul(transpose(b),igv_(:,i1))*alat(:)/2.0_SP/pi
        g_vec(2*i1-1,:)  =-matmul(transpose(b),igv_(:,i1))*alat(:)/2.0_SP/pi
     enddo
     !
   else
     !
     do i1 = 1, ng_vec
       g_vec(i1,:)=matmul(transpose(b),igv_(:,i1))*alat(:)/2.0_SP/pi ! ok
     enddo
     !
   endif

!  deallocate(igv_)
   !
 end subroutine get_R_vectors
 !
 !---------------------------------------------------------------------*
 !    Read IGK arrays                                                  *
 !---------------------------------------------------------------------*
 !
 subroutine get_IGK(k)
   use wave_func,             ONLY : wf_nc_k, wf_ncx, wf_igk, wf_ng
   use R_lattice,             ONLY : bz_samp, ng_vec
   use mod_com2y,             ONLY : force_noWFs
   use com,                   ONLY : msg, error
   character(lchlen) :: lch
   type(bz_samp) :: k
   integer i1,ik
   !
   allocate( wf_nc_k(k%nibz) )

#if defined _P2Y_EXPORT

   allocate( pw_igk_(wf_ncx, k%nibz))
   allocate( pw_npwk_(k%nibz) )
   call pw_igkindex(pw_unit)
   wf_nc_k(:) = pw_npwk_(:)
   deallocate(pw_npwk_)

#elif defined _P2Y_V31  || defined _P2Y_V311 

   allocate( pw_igk_(ngm_, k%nibz))
   allocate(index_(ngm_))     ! avoid allocate(index_(wf_ncx)) in case of v3.1 bug
   do ik = 1, k%nibz
     !
     pw_igk_(1:ngm_, ik)= 0
     wf_nc_k(ik) =0
     !
     ! Print verbose wfc read message
     !
     if(verboseIO.and.(any( (/1,2,k%nibz/)-ik.eq.0 ) &
&                      .or.mod(ik,k%nibz/4).eq.0)) then
       write(lch,'(" :: K-point:",i5,"/",i5)' ) ik,k%nibz
       call msg('s',trim(lch))
     endif

     call qexml_read_gk(ik, npwk=npwk_, index=index_, ierr=ierr)
     if (ierr.ne.0) call errore('qexml_read_gk','IOTK error',ABS(ierr))
  
!    if(npwk_.gt.wf_ncx) then
!      call msg('s','PWscf v3.1 contains a bug for parallel jobs.')
!      call msg('s','The tag <MAX_NPW> is incorrect      :',wf_ncx)
!      call msg('s','as it is less than npwk for some k  :',npwk_)
!      call msg('s','Action: fix MAX_NPW in data-file.xml manually,')
!      call msg('s','or use pw_export, 3.1.1 or 3.2 instead.')
!      call error('MAX_NPW < gkvectors size. See report file for details.')
!    endif
     pw_igk_(1:npwk_, ik)= index_(1:npwk_) 
     wf_nc_k(ik) = npwk_
   enddo
   deallocate(index_)
!
! This is a correct definition of wf_ncx only if gamma_only = .false.
!
!  wf_ncx = maxval(wf_nc_k)  

#elif defined _P2Y_V32 || defined _P2Y_V40 || defined _P2Y_V50

   allocate( pw_igk_(npwx_, k%nibz))
   allocate( index_(npwx_) )     
   do ik = 1, k%nibz
     call qexml_read_gk(ik, npwk=npwk_, index=index_, ierr=ierr)
     if (ierr.ne.0) call errore('qexml_read_gk','IOTK error',ABS(ierr))
     pw_igk_(1:npwk_, ik)= index_(1:npwk_) 
     wf_nc_k(ik) = npwk_
   enddo
   deallocate(index_)
     
#endif

   allocate( wf_igk(wf_ncx, k%nibz) )  ! this will be incorrect for parallel 3.1
   wf_igk(:,:)=-1 ! for checking

   if(gamma_only_) then
     do i1 = 1,k%nibz
        wf_igk(1,i1)=pw_igk_(1,i1)
        do i2=2,wf_nc_k(i1)
           wf_igk(2*i2-2,i1)=pw_igk_(i2,i1)*2-2
           wf_igk(2*i2-1,i1)=pw_igk_(i2,i1)*2-1
        enddo
        !
        ! NB: Extension of wf_nc_k array also done here.
        !
        wf_nc_k(i1)=2*(wf_nc_k(i1)-1)+1
     enddo
   else
     do i1 = 1,k%nibz
       wf_igk(1:wf_nc_k(i1),i1)= pw_igk_(1:wf_nc_k(i1),i1) 
     enddo   
   endif
   deallocate(pw_igk_)

   wf_ng = maxval(wf_igk)
   !
   ! Inportant check on wf_ncx.
   !
   if(maxval(wf_nc_k).ne.wf_ncx) then
     call error('maxval(wf_nc_k).ne.wf_ncx ! Check MAX_NPW/MAX_NUMBER_GK_VECTORS ')
   endif
   if(any(wf_nc_k.eq.0)) call error('At least one npw(k) = 0!')
    
 end subroutine get_IGK
 !
 !---------------------------------------------------------------------*
 !    Read eigenvalues                                                 *
 !---------------------------------------------------------------------*
 !
 subroutine get_energies(en,k)
   !
   use electrons,  ONLY : levels, n_sp_pol
   type(bz_samp) :: k
   integer      :: ik_,ispin_
   type(levels) :: en
   !
   allocate( en%E(en%nb, k%nibz, n_sp_pol) )

#if defined _P2Y_EXPORT

   allocate(eig_(en%nb, k%nibz))

   call pw_eigenvalues(pw_unit)
    
   en%E(:,:,1) = eig_( 1:en%nb, 1:k%nibz )/2.0_DP ! pw_export in Hartree
    
#elif defined _P2Y_V31 || defined _P2Y_V311

   select case(n_sp_pol)
   case(1)
     allocate(eig_(en%nb, k%nibz))
     call qexml_read_bands(eig=eig_, ierr=ierr)
     if (ierr.ne.0) call errore('qexml_read_bands','IOTK error',ABS(ierr))
     en%E(:,:,1) = eig_( 1:en%nb, 1:k%nibz )
     deallocate(eig_)
   case(2)
     allocate(eig_s_(en%nb, k%nibz,n_sp_pol))
     call qexml_read_bands(eig_s=eig_s_, ierr=ierr)
     if (ierr.ne.0) call errore('qexml_read_bands','IOTK error',ABS(ierr))
     en%E(:,:,:) = eig_s_( 1:en%nb, 1:k%nibz, 1:n_sp_pol )
     deallocate(eig_s_)
   end select

#elif defined _P2Y_V32  || defined _P2Y_V40 || defined _P2Y_V50

   allocate(eigb_(en%nb))
   select case(n_sp_pol)
   case(2)
     do ik_ = 1,k%nibz
       do ispin_ = 1, n_sp_pol
         call qexml_read_bands(ik=ik_,ispin=ispin_,eig=eigb_, ierr=ierr)
         if (ierr.ne.0) call errore('qexml_read_bands','IOTK error',ABS(ierr))
         en%E(:,ik_,ispin_) = eigb_( 1:en%nb )
       enddo
     enddo
   case(1)
     do ik_ = 1,k%nibz
        call qexml_read_bands(ik=ik_,eig=eigb_, ierr=ierr)
        if (ierr.ne.0) call errore('qexml_read_bands','IOTK error',ABS(ierr))
        en%E(:,ik_,1) = eigb_( 1:en%nb )
     enddo
   end select
   deallocate(eigb_)

#endif
    
 end subroutine get_energies
 !
 !---------------------------------------------------------------------*
 !    Read XC functional                                               *
 !---------------------------------------------------------------------*
 !
 subroutine get_xc
   use com,        ONLY : warning,error
   use xc_functionals, ONLY: GS_xc_FUNCTIONAL, GS_xc_KIND, GS_exx_FRACTION, GS_exx_SCREENING      
   use mod_xc2y, ONLY: XC_yamboID,  XC_yamboID2kind
   implicit none
#if defined _P2Y_V31 || defined _P2Y_V32 || defined _P2Y_V311 || defined _P2Y_V40 || defined _P2Y_V50
   call qexml_read_xc(dft=pw_dft, lda_plus_u=pw_lda_plus_u, ierr=ierr)
   if(pw_lda_plus_u) call warning(' LDA+U. Hubbard correction is not considered in yambo.')
   GS_xc_FUNCTIONAL = XC_yamboID('pwscf_',pw_func=pw_dft)
   GS_xc_KIND       = XC_yamboID2kind(GS_xc_FUNCTIONAL)
#endif
#if defined _P2Y_V50
   call qexml_read_exx(exx_fraction=pw_exx_fraction, screening_parameter=pw_screening_parameter,& 
&                      exx_is_active=pw_exx_is_active,ierr=ierr)
   if (pw_exx_is_active) then 
      GS_exx_FRACTION = pw_exx_fraction
      GS_exx_SCREENING= pw_screening_parameter
   endif
#endif
 end subroutine get_xc
 !
end module p2y
