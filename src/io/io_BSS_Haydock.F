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
integer function io_BSS_Haydock(ID,it,BS_H_dim,reached_treshold,Af,Bf,Vnm1,Vn,Vnp1,Cf,Cf_kerr)  
 !
 use pars,          ONLY:SP
 use BS,            ONLY:BS_identifier
 use BS_solvers,    ONLY:BSS_q0
 use IO_m,          ONLY:io_connect,io_disconnect,io_elemental,&
&                        io_bulk,io_status,io_sec,io_header,&
&                        read_is_on,write_is_on
 !
 !
 !
 implicit none
 !
 integer             :: ID,it,BS_H_dim
 real(SP)            :: reached_treshold,Bf(it+1),Af(it)
 complex(SP)         :: Vnm1(BS_H_dim),Vn(BS_H_dim)
 complex(SP),optional:: Cf(it+1),Vnp1(BS_H_dim)
 complex(SP),optional:: Cf_kerr(it+1)
 !
 ! Work Space
 !
 integer  :: it_on_disk
 real(SP) :: V_dummy(BS_H_dim,2), Cf_dummy(it+1,2)
 !
 !
 io_BSS_Haydock=io_connect(desc='Haydock_restart',type=2,ID=ID)
 !
 if (io_BSS_Haydock<0) goto 1
 !
 if (any((/io_sec(ID,:)==1/))) then
   !
   io_BSS_Haydock=io_header(ID,XC_KIND="K_E force",GAUGE=.TRUE.,IMPOSE_GAUGE=.TRUE.)
   !
   call io_elemental(ID,VAR="PARS",VAR_SZ=6,MENU=0)
   call io_elemental(ID,VAR=&
&       " BSK Identifier                  :",I0=BS_identifier,CHECK=.TRUE.,OP=(/"=="/))
   call io_elemental(ID,VAR=&
&       " Haydock Iteration               :",I0=it,DB_I0=it_on_disk)
   call io_elemental(ID,VAR=&
&       " Haydock reached Treshold        :",R0=reached_treshold,&
&                                            DB_R0=reached_treshold)
   call io_elemental(ID,VAR=&
&       " Field direction                 :",R1=BSS_q0,CHECK=.true.,OP=(/"==","==","=="/))
   !
   call io_elemental(ID,VAR="",VAR_SZ=0,MENU=1)
   !
   ! ioBSS_Haydock due to the header
   !
   if (io_BSS_Haydock<0) goto 1
   !
   io_BSS_Haydock=io_status(ID)
   if (io_BSS_Haydock<0) goto 1
   !
   io_BSS_Haydock=it_on_disk
   !
 endif
 !
 if (any((/io_sec(ID,:)==2/))) then
   !
   ! Vnm1
   !
   if (write_is_on(ID)) V_dummy(:,1)=real(Vnm1)
   if (write_is_on(ID)) V_dummy(:,2)=aimag(Vnm1)
   call io_bulk(ID,'Vnm1',VAR_SZ=(/BS_H_dim,2/))
   call io_bulk(ID,R2=V_dummy)
   if (read_is_on(ID)) Vnm1(:)=V_dummy(:,1)+(0._SP,1._SP)*V_dummy(:,2)
   !
   ! Vn 
   !
   if (write_is_on(ID)) V_dummy(:,1)=real(Vn)
   if (write_is_on(ID)) V_dummy(:,2)=aimag(Vn)
   call io_bulk(ID,'Vn',VAR_SZ=(/BS_H_dim,2/))
   call io_bulk(ID,R2=V_dummy)
   if (read_is_on(ID)) Vn(:)=V_dummy(:,1)+(0._SP,1._SP)*V_dummy(:,2)
   !
   ! Af,Bf
   !
   call io_bulk(ID,'A_factors',VAR_SZ=(/it/))
   call io_bulk(ID,R1=Af)
   call io_bulk(ID,'B_factors',VAR_SZ=(/it+1/))
   call io_bulk(ID,R1=Bf)
   !
   ! Cf optional
   !
   if (present(Cf)) then 
     if (write_is_on(ID)) Cf_dummy(:,1)=real(Cf)
     if (write_is_on(ID)) Cf_dummy(:,2)=aimag(Cf)
     call io_bulk(ID,'C_factors',VAR_SZ=(/it+1,2/))
     call io_bulk(ID,R2=Cf_dummy)
     if (read_is_on(ID)) Cf(:)=Cf_dummy(:,1)+(0._SP,1._SP)*Cf_dummy(:,2)
   endif
   !
   !
   !
   ! Vnp1 - optional
   !
   if (present(Vnp1)) then
     if (write_is_on(ID)) V_dummy(:,1)=real(Vnp1)
     if (write_is_on(ID)) V_dummy(:,2)=aimag(Vnp1) 
     call io_bulk(ID,'Vnp1',VAR_SZ=(/BS_H_dim,2/))
     call io_bulk(ID,R2=V_dummy)
     if (read_is_on(ID)) Vnp1(:)=V_dummy(:,1)+(0._SP,1._SP)*V_dummy(:,2)
   endif
   !
 end if
 !
1 call io_disconnect(ID=ID)
 !
end function
