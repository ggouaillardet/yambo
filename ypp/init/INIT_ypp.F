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
subroutine INIT_ypp(E,instr,lnstr,FINALIZE)
 !
 use YPP,            ONLY:l_plot,l_map_WFs,l_map_kpts,l_mag,l_k_grid,l_high_sym_pts,&
&                         l_free_hole,l_fix_syms,l_excitons,l_exc_wf,&
&                         l_amplitude,l_bands,l_bxsf,l_bz_grids,l_current,&
&                         l_density,l_dos,l_electrons,l_q_grid,l_QP_DBs_create_and_modify,&
&                         l_QP_DBs_merge,l_random_grid,l_shifted_grid,l_sort,l_sp_wf,l_spin,&
&                         l_wannier,l_wavefunction,MAX_DbGd_DBs,n_DbGd_DBs,n_u_interp_pts,n_u_k_pts,n_u_q_pts,&
&                         U_k_pts,U_interp_pts,U_q_pts,U_q_shifts,DbGd_DB1_paths
 use pars,           ONLY:pi,SP,schlen
 use D_lattice,      ONLY:i_time_rev
 use it_m,           ONLY:initdefs,initmode,ofiles_append,&
&                         initinfio,infile,infile_dump,initactivate,&
&                         nrnlvls,rnlvls,runlevel_is_on,&
&                         infile_verbosity,V_general,V_qp,V_all,V_real_time
 use drivers,        ONLY:infile_editing
 use com,            ONLY:file_exists
 use stderr,         ONLY:string_split
 use electrons,      ONLY:n_spin,n_spinor,levels
 use parallel_m,     ONLY:master_cpu,PP_redux_wait
 use LIVE_t,         ONLY:what_is_running
#if defined _YPP_ELPH
 use YPP_ELPH
#endif
 !
 implicit none
 !
 type(levels)     ::E
 integer          ::lnstr
 character(lnstr) ::instr
 logical          ::FINALIZE
 !
 ! Work Space
 !
 logical          ::l_init_QP,l_flag
 type(initdefs)   ::defs
 integer          ::i1,i2
 character(schlen)::rstr_piece(60) 
 !
 integer, external::parse_character_arrays
 !
 ! What is running ?
 !
 what_is_running='YPP'
#if defined _YPP_ELPH
 what_is_running='YPP_PH'
#endif
 !
 if (FINALIZE) then
   call call_INIT_load('GameOver')
   if (master_cpu) call ofiles_append(defs=defs)
   return
 endif
 !
 call YPP_SET_defaults()
 !
 ! DATABASES 
 !===========
 !
 !
 !
 ! Defaults->Defs + Initialization
 !
 call call_INIT_load('load')
 !
 ! Dump internally the input file
 !
 if (file_exists(trim(infile))) then
   !
   call infile_dump()
   !
 endif
 !
 ! RunLevels on
 !
 call string_split(instr,rstr_piece)
 do i1=1,50
   if ( trim(rstr_piece(i1))=="jobstr" ) cycle
   if ( i1>1) then
     if (trim(rstr_piece(i1-1))=="jobstr" ) cycle
   endif
   !
   ! Verbosity
   !
   if (i1<50) then
     if( trim(rstr_piece(i1)) == 'infver' .and. trim(rstr_piece(i1+1))=='gen' ) infile_verbosity=V_general
     if( trim(rstr_piece(i1)) == 'infver' .and. trim(rstr_piece(i1+1))=='rt' )  infile_verbosity=V_real_time
     if( trim(rstr_piece(i1)) == 'infver' .and. trim(rstr_piece(i1+1))=='qp' )  infile_verbosity=V_qp
     if( trim(rstr_piece(i1)) == 'infver' .and. trim(rstr_piece(i1+1))=='all' ) infile_verbosity=V_all
   endif
   !
   call initactivate(1,'ElecTemp BoseTemp')
   !
   do i2=1,nrnlvls
     if ( trim(rstr_piece(i1)) == trim(rnlvls(i2,1)) ) then
       infile_editing=.true.
       call initactivate(1,trim(rnlvls(i2,1)))
     endif
   enddo
   !
   if ( trim(rstr_piece(i1)) == 'bzgrids') then
     l_k_grid=trim(rstr_piece(i1+1))=='k'
     l_q_grid=trim(rstr_piece(i1+1))=='q'
     l_shifted_grid=trim(rstr_piece(i1+1))=='s'
     l_random_grid=trim(rstr_piece(i1+1))=='r'
     !
     !
     if (l_k_grid) call initactivate(1,"K_grid")
     if (l_q_grid) call initactivate(1,"Q_grid")
     if (l_shifted_grid) call initactivate(1,"Shifted_Grid")
     if (l_random_grid)  call initactivate(1,"Random_Grid")
     if (l_high_sym_pts) call initactivate(1,"High_Symm")
   endif
   !
   if ( trim(rstr_piece(i1)) == 'QPDBs') then
     call initactivate(1,'QPDBs')
     l_QP_DBs_create_and_modify=trim(rstr_piece(i1+1))=='g'
     l_QP_DBs_merge            =trim(rstr_piece(i1+1))=='m'
     if (l_QP_DBs_create_and_modify) call initactivate(1,'QPDB_edit')
     if (l_QP_DBs_merge)             call initactivate(1,'QPDB_merge')
   endif
   !
#if defined _YPP_ELPH
   if ( trim(rstr_piece(i1)) == 'phonons') then
     l_dos              =trim(rstr_piece(i1+1))=='d'
     l_eliashberg       =trim(rstr_piece(i1+1))=='e'
     l_atomic_amplitude =trim(rstr_piece(i1+1))=='a'
     if (l_atomic_amplitude) infile_editing=.false.
     if (l_eliashberg)   call initactivate(1,'eliashberg')
   endif
#endif
   if ( trim(rstr_piece(i1)) == 'excitons') then
     l_wavefunction   =trim(rstr_piece(i1+1))=='w'
     l_sort           =trim(rstr_piece(i1+1))=='s'
     l_amplitude      =trim(rstr_piece(i1+1))=='a'
#if defined _YPP_ELPH
     l_gkkp           =trim(rstr_piece(i1+1))=='g'
#endif
     !
     l_spin  =trim(rstr_piece(i1+1))=='sp'.and.n_spin>1
     l_mag   =trim(rstr_piece(i1+1))=='m'.and.n_spin>1
     !
     !
   endif
   if ( trim(rstr_piece(i1)) == 'electrons') then
     !
     l_current        =trim(rstr_piece(i1+1))=='c'
     l_density        =trim(rstr_piece(i1+1))=='d'
     l_dos            =trim(rstr_piece(i1+1))=='s'
     l_wavefunction   =trim(rstr_piece(i1+1))=='w'
     l_bands          =trim(rstr_piece(i1+1))=='b'
     l_mag            =trim(rstr_piece(i1+1))=='m'.and.n_spin>1
     !
#if defined _YPP_ELPH
     l_eliashberg       =trim(rstr_piece(i1+1))=='e'
#endif
     !
     !
   endif
   !
   !    
   if ( trim(rstr_piece(i1)) == 'excitons'.or. trim(rstr_piece(i1)) == 'electrons') then
     if (l_amplitude)      call initactivate(1,'amplitude')
     if (l_spin)           call initactivate(1,'spin')
     if (l_mag)            call initactivate(1,'magnetization')
     if (l_wavefunction)   call initactivate(1,'wavefunction')
#if defined _YPP_ELPH
     if (l_eliashberg)       call initactivate(1,'eliashberg')
     if (l_gkkp)             call initactivate(1,'gkkp')
#endif
     if (l_current)        call initactivate(1,'current')
     if (l_density)        call initactivate(1,'density')
     if (l_sort)           infile_editing=.false.
   endif
   if ( trim(rstr_piece(i1)) == 'phonons'.or. trim(rstr_piece(i1)) == 'electrons') then
     if (l_dos)            call initactivate(1,'dos')
   endif
   if ( trim(rstr_piece(i1)) == 'electrons') then
     if (l_bands)          call initactivate(1,'bnds')
   endif
 enddo
 !
 l_flag=.not.l_sort
#if defined _YPP_ELPH
 l_flag=.not.l_sort.and..not.l_atomic_amplitude
#endif
 if (l_flag) call call_INIT_load('parserload')
 !
 l_bz_grids  = runlevel_is_on('bzgrids')
 l_k_grid    = runlevel_is_on('K_grid')
 l_q_grid    = runlevel_is_on('Q_grid')
 l_shifted_grid = runlevel_is_on('Shifted_Grid')
 l_random_grid  = runlevel_is_on('Random_Grid')
 l_high_sym_pts = runlevel_is_on('High_Symm')
 l_dos       =runlevel_is_on('dos')
 l_bands     =runlevel_is_on('bnds')
 l_fix_syms  =runlevel_is_on('fixsyms')
#if defined _YPP_ELPH
 l_eliashberg=runlevel_is_on('eliashberg')
 l_phonons   =runlevel_is_on('phonons')
 l_gkkp      =runlevel_is_on('gkkp')
#endif
 l_excitons =runlevel_is_on('excitons')
 l_electrons=runlevel_is_on('electrons')
 l_plot=any((/runlevel_is_on('wavefunction'),runlevel_is_on('magnetization'),&
&             runlevel_is_on('density'),runlevel_is_on('current')/))
 l_free_hole=runlevel_is_on('freehole')
 l_amplitude=runlevel_is_on('amplitude')
 l_exc_wf   =runlevel_is_on('wavefunction').and.runlevel_is_on('excitons')
 l_sp_wf    =runlevel_is_on('wavefunction').and.runlevel_is_on('electrons')
 l_density  =runlevel_is_on('density').and.runlevel_is_on('electrons')
 l_current  =runlevel_is_on('current').and.runlevel_is_on('electrons')
 l_mag      =runlevel_is_on('magnetization')
 l_wannier  =runlevel_is_on('wannier')
 l_spin     =runlevel_is_on('spin')
 !
 if (.not.l_exc_wf) l_free_hole=.false.
 !
 if (l_bz_grids) then
   call initactivate(1,"NoWeights OutputAlat")
   if (l_k_grid)        call initactivate(1,"cooIn cooOut ListPts ExpandPts")
   if (l_q_grid)        call initactivate(1,"cooIn cooOut ListPts ExpandPts ForceUserPts")
   if (l_high_sym_pts)  call initactivate(1,"cooIn cooOut PtsPath NPtsPath")
   if (l_shifted_grid)  call initactivate(1,"cooIn cooOut")
   if (l_random_grid)   call initactivate(1,"cooOut BZ_random_Nk GammaRadius")
 endif
 !
 if ((l_dos.or.l_bands).and.n_spinor==2) call initactivate(1,'WFReference')
 !
 if (l_bands) call initactivate(1,"cooIn BANDS_steps INTERPGrid ShellFac NormN NelFac")
 !	   
 l_map_kpts  = runlevel_is_on('kpts_map')
 !
 l_map_WFs   = runlevel_is_on('WFs_map')
 !
 l_bxsf      = runlevel_is_on('bxsf')
 !
 if (l_bxsf) call initactivate(1,"W90_fname WannBnds DgridOrd")
 !
 l_QP_DBs_create_and_modify = runlevel_is_on('QPDB_edit')
 l_QP_DBs_merge = runlevel_is_on('QPDB_merge')
 !
 !
 if (l_fix_syms.and.n_spinor==2.and.i_time_rev==0) call initactivate(1,"ExpandSymm")
 !
 
 if (l_fix_syms) call initactivate(1,"RmAllSymm RmTimeRev")
 
 !
 !
 !
 if (l_map_kpts) call initactivate(1,"BZ_DbGd_nkpts SkipCheck noBZExpand NoWeights")
 !
 if (l_map_WFs)  call initactivate(1,"SOC_DBs SOC_splitting bands_to_map bands_buffer")
 !
 if (l_electrons) then
   if (l_dos.or.l_bands) call INIT_QP_ctl_switch('G')
   if (l_dos) call initactivate(1,"DOSERange DOSESteps DOS_broad DOS_bands PrtOccOnly")
 endif
 !
 !
 if (l_plot) then
   call initactivate(1,"Format Direction FFTGvecs") 
   if (l_sp_wf) call initactivate(1,"Degen_Step")  
#if defined _YPP_ELPH
   if (l_sp_wf) call initactivate(1,"ResTresh")  
#endif
   if (l_mag)   call initactivate(1,"MagDir") 
   if (l_current) call initactivate(1,'CurrentDir')
 endif
 !
 if (l_excitons) then
   call initactivate(1,"States")
   if (l_amplitude) then
     call INIT_QP_ctl_switch('G')
     call initactivate(1,"DipWeight")
   endif
   if (l_exc_wf.or.l_amplitude) call initactivate(1,"Degen_Step MinWeight")
   if (l_exc_wf.and..not.l_free_hole) call initactivate(1,"Cells Hole Dimension") 
   if (l_exc_wf.and.l_free_hole) call initactivate(1,"WFMult") 
   if (l_spin) call initactivate(1,"Degen_Step FFTGvecs")
#if defined _YPP_ELPH
   if (l_eliashberg)  call initactivate(1,"Degen_Step") 
#endif
 endif
 !
#if defined _YPP_ELPH
 if (l_gkkp.and..not.l_excitons)   call initactivate(1,"DBsPATH PHfreqF PHmodeF GkkpExpand")
 if (l_phonons.and.l_eliashberg)   call initactivate(1,"EE_Fermi EfGbroad")
 if ( ((l_excitons.or.l_electrons).and.l_eliashberg) .or. (l_phonons.and.l_dos) ) call initactivate(1,"PhBroad PhStps")
#endif
 !
 !
 ! Check for existing QP control fields to be proposed in the new input files
 !
 call QP_state_table_setup(E)
 !
 if (infile_editing) then
   open(unit=12,file=trim(infile))
   call initinfio(defs,12)
   close(12)
   call PP_redux_wait
 endif
 !
 if (l_QP_DBs_create_and_modify.or.l_QP_DBs_merge) call QP_DBs_initialize()
 !
 l_init_QP=(l_plot.and.l_sp_wf).or.l_bands
#if defined _YPP_ELPH
 if (.not.l_init_QP) l_init_QP=l_electrons.and.l_eliashberg
#endif
 !
 if (l_init_QP) call INIT_QP(.FALSE.,.FALSE.)
 !
 ! Check and fill all possible vectorial USER fields
 !
 l_flag=l_bands
 if (l_flag) call USER_vector_handle("BKpts")
 !
 if (l_bz_grids) then
   if (l_k_grid)       call USER_vector_handle("GWKpts")
   if (l_q_grid)       call USER_vector_handle("Qpts")
   if (l_shifted_grid) call USER_vector_handle("KShift")
 endif
 !
 if (l_map_kpts) then
   n_DbGd_DBs=parse_character_arrays(DbGd_DB1_paths,MAX_DbGd_DBs,"DbGd_DB1_paths"," ",.TRUE.)
   if (infile_editing) i1=parse_character_arrays(DbGd_DB1_paths,n_DbGd_DBs,&
&              "DbGd_DB1_paths","Paths to the SAVE folders with the Double Grid DB1",.FALSE.)
 endif
 !
contains
 !
 subroutine call_INIT_load(mode) 
   character(*)::mode
   !
   if (mode=='load')       initmode=0
   if (mode=='todef')      initmode=1
   if (mode=='Gclose')     initmode=2
   if (mode=='GameOver')   initmode=3
   if (mode=='parserload') initmode=4
   call ypp_INIT_load(defs)
   !
 end subroutine
 !
 subroutine USER_vector_handle(field)
   !
   use parser_m,       ONLY:parser
   use it_m,           ONLY:nflines,flines,nADDITIONAL_flines,ADDITIONAL_flines
   !
   character(*):: field
   !
   integer     :: n_points,i_p,nflines_save
   real(SP)    :: real_ctl,real_v(10,3)
   !
   real_ctl=0._SP
   real_v(:,3)=999._SP
   call parser(field,real_v)
   !
   !
   do i_p=1,10
     if (real_v(i_p,3)==999._SP) exit
   enddo
   !
   n_points=i_p-1
   !
   if (n_points==0) then
     n_points=1
     real_v(1,:)=0._SP
   endif
   !
   if (field=="KShift") then
     n_points=3
     real_v(:,:)=0._SP
     do i_p=1,3
       real_v(i_p,i_p)=5.E-5_SP
     enddo
   endif
   !
   ADDITIONAL_flines = " "
   nADDITIONAL_flines= 0
   !
   nflines_save=nflines
   if (field=="GWKpts") then
     write (flines(nflines+1),'(a,t30,a)') '%'//field,'# K points list'
     n_u_k_pts=n_points
     U_k_pts(:n_u_k_pts,:)=real_v(:n_u_k_pts,:)
   else if (field=="BKpts") then
     write (flines(nflines+1),'(a,t30,a)') '%'//field,'# K points of the bands circuit'
     n_u_interp_pts=n_points
     U_interp_pts(:n_u_interp_pts,:)=real_v(:n_u_interp_pts,:)
   else if (field=="Qpts") then
     write (flines(nflines+1),'(a,t30,a)') '%'//field,'# Q points list'
     n_u_q_pts=n_points
     U_q_pts(:n_u_q_pts,:)=real_v(:n_u_q_pts,:)
   else if (field=="KShift") then
     write (flines(nflines+1),'(a,t30,a)') '%'//field,'# K-grid shifts (max 3)'
     U_q_shifts(:n_points,:)=real_v(:n_points,:)
   endif
   !
   nflines=nflines+1
   do i_p=1,n_points
     write (flines(nflines+1),'(4(f7.5,1x,a))') real_v(i_p,1),'|', real_v(i_p,2),'|', real_v(i_p,3),'|'
     nflines=nflines+1
   enddo
   write (flines(nflines+1),'(a)') '%'
   nflines=nflines+1
   !
   if (infile_editing) open(unit=12,file=trim(infile),position='append')
   do i1=nflines_save+1,nflines
     nADDITIONAL_flines=nADDITIONAL_flines+1
     ADDITIONAL_flines(nADDITIONAL_flines)=flines(i1)
     if (infile_editing) write (12,'(a)') trim(flines(i1))
   enddo 
   if (infile_editing) close(12)
   !
 end subroutine
 !
end subroutine
