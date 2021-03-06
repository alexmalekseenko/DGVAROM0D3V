!
!  DGV_data_driven_boltz.f90
!
! This module contains routines that are involved in the evaluation of the spatial operator  
!
!
!!!!!!!!!!!!!!!!!!!!!
! the present code modification is designed to accomplish tasks relevant to the data driven solution of the BE.
! The following tasks are implemented: 
!
! 1. the code will read an array of VDFs and compute the collision operator for that vdf. 
!    The results are saved in the large array of the same size
!    
!    To make this possible, subroutines were created to 
!    a. read the VDFs into an array
!    b. compute the collision integral for these VDFS. 
!    c. record the results on the hard drive
!
! 2. the code will prepare a collision kernel computed for some global basis functions. 
!
!
! 3. Subr
!
!!!!!!!!!!!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

module DGV_data_driven_boltz
use nrtype ! contains kind parameters (DP), (DP), (I4B) etc. 
   implicit none


real (DP), dimension (:,:), allocatable :: sol_array ! arrays to store values of solution files that we read from the hard drive and the corresponding 
                                      ! array to store the outputs of the collsiion operator
real (DP), dimension (:,:), allocatable :: Projector ! These is the matrix that will do projection and recovery of the ROM model
real (DP), dimension (:,:), allocatable :: LinROMKrnl ! These is the matrix will contain linear kernel for the ROM model. Only is used if SV Zero Basis is used.

real (DP), dimension (:), allocatable :: ROMKrnl ! This is an array that will keep the components of the singular vector collision kernel

!!!!!!!!!!!!!!!!!!!!!!!!!!
character (len=132) :: name_solutions_file_read  ! name of the file that contains solutions/VDFs that will be read from the drive to prepare data 
character (len=132) :: SVKrnl_name ! the variable to store the name of the output collision kernel data file 
character (len=132) :: SVLinKrnl_name ! the variable to store the name of the Linear collision kernel data file -- used with the SV Zero Basis 
character (len=132) :: SVfile_name ! the variable to store the name of the file where svd vectors are stored.
integer (I4B) :: si_start ! the number of the first entry of the collision kernel array to compute -- using single inmdex and the above numbering conventions
integer (I4B) :: si_end   ! the number of the last entry of the collision kernel array to compute 
integer (I4B) :: num_SVKernl_chnks     ! components of signular Vector kernel may be computed in portions and stored in multiple files, call chunks. This parameter give the total number of chunks. 
                                       ! chunk enumeration starts from 0.
                                       
integer (I4B) :: k_tgt, i_start, i_end ! k_tgt - target size of the ROM basis. i_start and i_end --- parameters determining the portiopn of the ROM binary 
                                       ! kernel to be computed using the Mk_Coll_Ker_SVD_Basis_MACRO_Optml subroutine.                                        
logical :: flag_SVZeroBasisInUse    ! this variable will keep a flag indicating that SV  Zero Basis is in use -- this will call for different collision operator, compared to other bases.                                    

contains 

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!! This module will have a shrot dedicated parameter file. 
!!
!! Here is a subrouine that reads it. 
!!
!! This is just a copy of the subroutine that reads DGVparameters.dat of similar. 
!! Instead of complimenting the main subrouine, we will create a specialized one.
!! 
!!
!!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! SetDGVParams_DataDrivenBLZM(pfname,slt)
!
! slt == paramters determining if the print out is generated. If s=0 then there is a printout, 
! if slt is any other number, then no
!
! This subroutine reads the variables from the 
! parameter file on the hard drive. The variables 
! from the common variabl block are accessed directly
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

subroutine SetDGVParams_DataDrivenBLZM(pfname,slt)

use DGV_readwrite

intrinsic Real,Index, Len, Scan, Trim

character (len=*), intent (in) :: pfname ! Name of the file where the parameters are stored 
integer, intent (in) :: slt ! parameter detemining if the prinout is generated. If == 0 then printout generated. 

character (len=132) :: line              ! string to keep one record 
character (len=10) :: fmtchar            ! string to keep format 
character (len=50) :: line_head          ! string to keep the line header 
integer (I4B) :: code_file, code_line          ! get the return code from READ
integer (I4B) :: m_count                            ! dump counter 
integer (I4B) :: pos                 ! to store position within the string 
integer (I4B), dimension (20) :: i_bulk  ! to store temporarily integers that has been read from the parameter file 
real (DP), dimension (20) :: r_bulk      ! to store temporarily reals that has been  read from the parameter file 
integer (I4B) :: loc_alloc_stat ! some dump varaible
!
open (15, file=pfname, position ="REWIND", action="READ") ! open the file for reading
code_file=0
do while (code_file == 0)
 read (15, "(A)", iostat=code_file)  line                               ! read one line
 pos = Scan(line, "=")
 if ((pos /= 0) .and. (line(1:1)/="!")) then
  write (fmtchar, "(I3)") pos-1 
  read (line, "(A"//trim(fmtchar)//")", iostat = code_line ) line_head  
  line_head = trim(line_head)
  line(:) = line(pos+1:)   ! remove the heading from the line 
  !
  pos = Scan(line, "!")
  if (pos > 1) then 
  line(:) = trim(line(:pos-1))   ! remove any comments from the line
  end if 
  ! 
  select case (line_head)
   !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!  
   case ("name sol file read")         ! ready to set name of the directory to store soltuion and other files 
    !!! We read the parameter from the input line 
    if ((line == "") .or. (line == " ")) then 
     name_solutions_file_read = "defautSolReadName"
    else
     name_solutions_file_read = Trim(Adjustl(line))
    end if
    if (slt==0) then  
     print *, "name_solutions_file_read=", name_solutions_file_read 
    end if
   case ("name sing vec file read")         ! ready to set name of the directory to store soltuion and other files 
    !!! We read the parameter from the input line 
    if ((line == "") .or. (line == " ")) then 
     SVfile_name = "defautSVDReadName"
    else
     SVfile_name = Trim(Adjustl(line))
    end if
    if (slt==0) then  
     print *, "SVfile_name=", SVfile_name
    end if
   case ("header s vec kernel file")         ! ready to set name of the directory to store soltuion and other files 
    !!! We read the parameter from the input line 
    if ((line == "") .or. (line == " ")) then 
     SVKrnl_name = "defautSVKrnlName"
    else
     SVKrnl_name = Trim(Adjustl(line))
    end if
    if (slt==0) then  
     print *, "SVKrnl_name=", SVKrnl_name 
    end if
   case ("header SVzr lin ker file")         ! ready to set name of the directory to store soltuion and other files 
    !!! We read the parameter from the input line 
    if ((line == "") .or. (line == " ")) then 
     SVLinKrnl_name = "defautSVLinKrnlName"
    else
     SVLinKrnl_name = Trim(Adjustl(line))
    end if
    if (slt==0) then  
     print *, "SVLinKrnl_name=", SVLinKrnl_name 
    end if
    
   case ("first entry svkernel")  ! ready to set up the number of chunks in A arrays 
    !!! First we read the parameters from the input line
    call ReadIntegersFromLine(line_head, line, i_bulk, m_count, 1) ! last parameter is the default value for the paramenter to be read 
    if (m_count > 0) then 
     si_start=i_bulk(1) ! all other inputs values are ignored 
    else 
     si_start=0 ! set up to the default value 
    end if 
    if (slt==0) then 
     print *, "si_start=", si_start 
    end if     
   case ("last entry svkernel")  ! ready to set up the number of chunks in A arrays 
    !!! First we read the parameters from the input line
    call ReadIntegersFromLine(line_head, line, i_bulk, m_count, 1) ! last parameter is the default value for the paramenter to be read 
    if (m_count > 0) then 
     si_end=i_bulk(1) ! all other inputs values are ignored 
    else 
     si_end=0 ! set up to the default value 
    end if 
    if (slt==0) then 
     print *, "si_end=", si_end 
    end if     
   case ("number of svkernel chunks")  ! ready to set up the number of chunks in A arrays 
    !!! First we read the parameters from the input line
    call ReadIntegersFromLine(line_head, line, i_bulk, m_count, 1) ! last parameter is the default value for the paramenter to be read 
    if (m_count > 0) then 
     num_SVKernl_chnks=i_bulk(1) ! all other inputs values are ignored 
    else 
     num_SVKernl_chnks=0 ! set up to the default value 
    end if 
    if (slt==0) then 
     print *, "num_SVKernl_chnks=", num_SVKernl_chnks 
    end if   
   case ("target size ROM basis")  ! ready to set up the number of chunks in A arrays 
    !!! First we read the parameters from the input line
    call ReadIntegersFromLine(line_head, line, i_bulk, m_count, 1) ! last parameter is the default value for the paramenter to be read 
    if (m_count > 0) then 
     k_tgt=i_bulk(1) ! all other inputs values are ignored 
    else 
     k_tgt=0 ! set up to the default value 
    end if 
    if (slt==0) then 
     print *, "k_tgt=", k_tgt  
    end if      
   case ("first i svkernel")  ! ready to set up the number of chunks in A arrays 
    !!! First we read the parameters from the input line
    call ReadIntegersFromLine(line_head, line, i_bulk, m_count, 1) ! last parameter is the default value for the paramenter to be read 
    if (m_count > 0) then 
     i_start=i_bulk(1) ! all other inputs values are ignored 
    else 
     i_start=0 ! set up to the default value 
    end if 
    if (slt==0) then 
     print *, "i_start=", i_start 
    end if   
   case ("last i svkernel")  ! ready to set up the number of chunks in A arrays 
    !!! First we read the parameters from the input line
    call ReadIntegersFromLine(line_head, line, i_bulk, m_count, 1) ! last parameter is the default value for the paramenter to be read 
    if (m_count > 0) then 
     i_end=i_bulk(1) ! all other inputs values are ignored 
    else 
     i_end=0 ! set up to the default value 
    end if 
    if (slt==0) then 
     print *, "i_end=", i_end 
    end if      
   case ("use SV Zero basis")        ! ready to set up mesh in u is uniform parameter 
    !!! We read the parameter from the input line 
    if ((trim(Adjustl(line)) == "YES") .or. (trim(Adjustl(line)) == "yes") .or. (trim(Adjustl(line)) == "Yes")) then 
     flag_SVZeroBasisInUse = .TRUE.
    else
     flag_SVZeroBasisInUse = .FALSE.
    end if
    if (slt==0) then 
     print *, "flag_SVZeroBasisInUse=", flag_SVZeroBasisInUse 
    end if 
   case default
    if (slt==0) then  
     print *, "Can not process:" //line_head // "="// line
     end if   
   end select
 else
  if (slt==0) then  
   print *, line
  end if  
 end if   
 end do 
close(15)
end subroutine SetDGVParams_DataDrivenBLZM 


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! ReadArrysSols_DtaDrvnB
! 
!
! This subroutine will read the solutions file into an array sol_array
! 
!
!!!!!!!!!!!

subroutine ReadArrysSols_DtaDrvnB 

intrinsic Trim
!
character (len=132) :: file_name
integer (I4B) :: m,n ! the length of the arrays
integer (I4B) :: loc_alloc_stat ! some dump varaible


! first, we prepare the file name to store the solution
file_name = trim(Adjustl(name_solutions_file_read))//".dat"  ! this file will keep the array os folutions
!
! now we open the file for record and save some stuff in it: 
open (15, file=file_name, position ="REWIND", action="READ", &
                   form="UNFORMATTED", access="SEQUENTIAL")

read (15) m,n ! m gives the number of velocity nodes and n is the number of VDFs in the array 
! A quick check that the storages are the correct size: 
allocate (sol_array(1:m,1:n), stat=loc_alloc_stat)
    !
  if (loc_alloc_stat >0) then 
  print *, "ReadArrysSols_DtaDrvnB: Allocation error for variable sol_array"
  close(15)
  stop
  end if
read (15) sol_array
close (15)

end subroutine ReadArrysSols_DtaDrvnB  

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! WriteArryColl_DtaDrvnB
! 
!
! This subroutine will read the solutions file into an array sol_array
! 
!
!!!!!!!!!!!

subroutine WriteArryColl_DtaDrvnB(fcol_arry) 

intrinsic Trim
!
real (DP), dimension(:,:), intent(in) :: fcol_arry ! the array of values of collision operator
!
integer (I4B) :: m,n ! the length of the arrays
integer (I4B) :: loc_alloc_stat ! some dump varaible
character (len=132) :: file_name !


! first, we prepare the file name to store the solution
file_name = trim(Adjustl(name_solutions_file_read))//"_collDta.dat"  ! this file will keep the array of collision operators
!
! now we open the file for record and save some stuff in it: 
open (15, file=file_name, position ="REWIND", action="WRITE", &
                   form="UNFORMATTED", access="SEQUENTIAL")

m=size(fcol_arry,1)
n=size(fcol_arry,2)
                   
write (15) m,n ! m gives the number of velocity nodes and n is the number of VDFs in the array 
! A quick check that the storages are the correct size: 
write (15) fcol_arry
close (15)
print *, "WriteArryColl_DtaDrvnB: successfully written copies of solution on the hard drive " 

end subroutine WriteArryColl_DtaDrvnB  





!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! ReadSingVect_DtaDrvnB(svdname,SVects)
! 
! This subroutine reads singular vectors from the hard drive. 
! SVects is an un-allocated pointer to a two indices. It will be allocated and filled with 
! singular vecotrs. the first index runs over the components of the singular vector and the second index
! runs over different vectors.  
! 
! svdname is the name of the file with full path where all singular vecotrs are stored. 
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine ReadSingVect_DtaDrvnB(svdname,SVects)

!                   
intrinsic Trim
!
character (len=132) :: svdname ! the variable to store the file name 
real (DP), dimension (:,:), pointer :: SVects ! array to keep singular vectors.
!
integer (I4B) :: mm,nn ! sizes of the array
integer (I4B) :: code_line ! scrap variable
integer (I4B) :: loc_alloc_stat ! to keep allocation status

! A quick check if the Arrays are already allocated
!if (size(SVects,1)>0) then
!   print *,"ReadSingVect_DtaDrvnB: A arrays are already allocated. Exit."
!   stop
!end if    

! now we open the file for reading and read some stuff from it: 
open (15, file=trim(Adjustl(svdname))//".dat", position ="REWIND", action="READ", &
                   form="UNFORMATTED", access="SEQUENTIAL")
read (15,  iostat = code_line) mm,nn ! notice that we read using one read statement because this is 
								! how it was written
close (15)

! We now need to prepare the storage for the data.
allocate (SVects(1:mm,1:nn), stat=loc_alloc_stat)
    !
  if (loc_alloc_stat >0) then 
  print *, "ReadSingVect_DtaDrvnB: Allocation error for variable  SVects"
  stop
  end if
open (15, file=trim(Adjustl(svdname))//".dat", position ="REWIND", action="READ", &
                   form="UNFORMATTED", access="SEQUENTIAL")
read (15, iostat = code_line) mm,nn ! notice that we read using one read statement because this is 
								    ! how it was written
read (15, iostat=code_line)	SVects  ! read the arrays SVects		
close (15)
!
end subroutine ReadSingVect_DtaDrvnB
!

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! WriteCKrnl_DtaDrvnB
! 
! This subroutine writes the arrays containing SVD-kernel on the disk
!
! 
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1

subroutine WriteCKrnl_DtaDrvnB(fname,CKrnl,si_start,si_end)
!                   
intrinsic Trim
!
character (len=132) :: fname ! the variable to store the file name 
real (DP), dimension (:), pointer :: CKrnl ! array to keep singular vectors.
integer (I4B), intent (in) :: si_start,si_end ! the starting and ending single index, that is the values of the indices that 
! correcpond to the first record of CKrnl and the last record. It is possible that not the entire but only a 
! portion of the  array is saved.

!!!!!!!!!! Debug !!!!!!!!!!!!!
call flush(6)
print *,"WriteCKrnl_DtaDrvnB: about to write CKrnl on the hard drive. CKrnl(1:5), size(CKrnl, 1):", &
           CKrnl(1:5), size(CKrnl, 1)
!!!!!!!!!! END Debug !!!!!!!!!!!!!

! now we open the file for record and save some stuff in it: 
open (15, file=trim(Adjustl(fname))//".dat", position ="REWIND", action="WRITE", &
                   form="UNFORMATTED", access="SEQUENTIAL")
! we record the size of the arrays
write (15) si_start,si_end
! now goes the error itself
write(15) CKrnl
!                 
close (15)
!
end subroutine WriteCKrnl_DtaDrvnB 

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! ReadCKrnl_DtaDrvnB
! 
! This subroutine reads cKrnl array is it is recored as a single file and not broken in chunks
!
! 
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

subroutine ReadCKrnl_DtaDrvnB(fname,CKrnl,sis,sie)
!                   
intrinsic Trim
!
character (len=132) :: fname ! the variable to store the file name 
real (DP), dimension (:), pointer :: CKrnl ! array to keep singular vectors.
integer (I4B), intent(out) :: sis, sie ! the starting and ending single index, that is the values of the indices that 
! correcpond to the first record of CKrnl and the last record. It is possible that not the entire but only a 
! portion of the  array is saved.

integer (I4B) :: code_line ! scrap variable
integer (I4B) :: loc_alloc_stat ! to keep allocation status

! now we open the file for record and save some stuff in it: 
open (15, file=trim(Adjustl(fname))//".dat", position ="REWIND", action="READ", &
                   form="UNFORMATTED", access="SEQUENTIAL")
! we record the size of the arrays
read (15) sis,sie
! 
close(15)
! We now need to prepare the storage for the data.
allocate (CKrnl(sis:sie), stat=loc_alloc_stat)
    !
  if (loc_alloc_stat >0) then 
  print *, "ReadCKrnl_DtaDrvnB: Allocation error for variable  CKrnl"
  stop
  end if
open (15, file=trim(Adjustl(fname))//".dat", position ="REWIND", action="READ", &
                   form="UNFORMATTED", access="SEQUENTIAL")
read (15, iostat = code_line) sis,sie ! notice that we read using one read statement because this is 
								    ! how it was written
read (15, iostat = code_line)	CKrnl  ! read the array CKrnl		7
!
close (15)
!
end subroutine ReadCKrnl_DtaDrvnB 

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! WriteBKrnl_DtaDrvnB
! 
! This subroutine writes the arrays containing linear SVD-kernel on the disk
!
! 
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!1

subroutine WriteBKrnl_DtaDrvnB(fname,BKrnl)
!                   
intrinsic Trim
!
character (len=132) :: fname ! the variable to store the file name 
real (DP), dimension (:,:), pointer :: BKrnl ! array to keep singular vectors.
integer (I4B) :: nsvs ! number of he singular vectors --- BKrnl is a qsquare matrix of nsvs x nsvs size 

!!!!!!!!!! Debug !!!!!!!!!!!!!
! call flush(6)
print *,"WriteBKrnl_DtaDrvnB: about to write CKrnl on the hard drive. BKrnl(1:5,1:5), size(BKrnl, 1):", &
           BKrnl(1:5,1:5), size(BKrnl, 1)
!!!!!!!!!! END Debug !!!!!!!!!!!!!
nsvs=size(BKrnl, 1)

! now we open the file for record and save some stuff in it: 
open (15, file=trim(Adjustl(fname))//"_Bkrnl.dat", position ="REWIND", action="WRITE", &
                   form="UNFORMATTED", access="SEQUENTIAL")
! we record the size of the arrays
write (15) nsvs
! now goes the error itself
write(15) BKrnl
!                 
close (15)
!
end subroutine WriteBKrnl_DtaDrvnB 

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! ReadBKrnl_DtaDrvnB
! 
! This subroutine reads BKrnl array
!
! 
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

subroutine ReadBKrnl_DtaDrvnB(fname,BKrnl,nsvs)
!                   
intrinsic Trim
!
character (len=132) :: fname ! the variable to store the file name 
real (DP), dimension (:,:), pointer :: BKrnl ! array to keep singular vectors.
integer (I4B), intent(out) :: nsvs ! number of he singular vectors --- BKrnl is a qsquare matrix of nsvs x nsvs size 

integer (I4B) :: code_line ! scrap variable
integer (I4B) :: loc_alloc_stat ! to keep allocation status

! now we open the file for record and save some stuff in it: 
open (15, file=trim(Adjustl(fname))//"_Bkrnl.dat", position ="REWIND", action="READ", &
                   form="UNFORMATTED", access="SEQUENTIAL")
! we record the size of the arrays
read (15) nsvs
! 
close(15)
!!
! We now need to prepare the storage for the data.
allocate (BKrnl(1:nsvs,1:nsvs), stat=loc_alloc_stat)
    !
  if (loc_alloc_stat >0) then 
  print *, "ReadBKrnl_DtaDrvnB: Allocation error for variable  BKrnl"
  stop
  end if
open (15, file=trim(Adjustl(fname))//"_Bkrnl.dat", position ="REWIND", action="READ", &
                   form="UNFORMATTED", access="SEQUENTIAL")
read (15, iostat = code_line) nsvs ! notice that we read using one read statement because this is 
								    ! how it was written
read (15, iostat = code_line) BKrnl  ! read the array BKrnl		7
!
close (15)
!
end subroutine ReadBKrnl_DtaDrvnB 



!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!  subroutine DGV_ROM_DtaDrvnColl_0D(f, coll)
!
!  This subroutine is evaluating an approximation of the Boltzmann collision operator using ROM that is obtained using 
!  a basis obtained by SVD of solutions to a class of problem. 
!
!  A solution on a discrete mesh is passed to the subroutine. It is projected to the low dimensional model. 
!  The collision operator is evaluated using m^3 where m is the dimensionality of the ROM. Then the low 
!  dimensional collision operator is recovered on the original mesh. 
!
! 
!  Make sure that Init0D_DataDrvnBoltzn is called before this subrouinte is used. It will set up the variables
! 
! 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine DGV_ROM_DtaDrvnColl_0D(f, coll)

intrinsic MATMUL

real (DP), dimension (:), intent (in) :: f ! array containing solution on the mesh
real (DP), dimension (:), intent (out) :: coll ! array containing solution on the mesh

!!!
real (DP), dimension (:), allocatable :: fproj ! ROM representation of the solution 
real (DP), dimension (:), allocatable :: collproj ! ROM representation of the solution 

!!!
integer (I4B) :: i,j,k,m, k_end, si ! Scrap counters
integer (I4B) :: mm ! num of records in singular vecotr
integer (I4B) :: loc_alloc_stat ! to keep allocation status

!!!! 
!! Matrices Project, Recover and ROMKrnl are set up by Init0D_DataDrvnBoltzn
!! Make sure Init0D_DataDrvnBoltzn has been called. 
!!!!
k_end = size(Projector,2) 
mm = size(Projector,1)

!!!!!!!!!!!! A couple os sanity checks: 
if (mm /= size(f,1)) then   ! these sizes have to be the same. There is more to it, but this is a first check
  print *, "DGV_ROM_DtaDrvnColl_0D: size of projection matrix does not match size of solution. Stop"
  stop
end if 
if (k_end*((k_end*(k_end+1))/2) /= size(ROMKrnl,1)) then   ! these sizes have to be the same. There is more to it, but this is a first check
  print *, "DGV_ROM_DtaDrvnColl_0D: size of ROM kernel array does not match size of ROM model. Stop "
  stop
end if 
!!!!!!!!!!!! end sanity check 

!!!!! Set up the array for the ROM variable: 
allocate (fproj(1:k_end),collproj(1:k_end), stat=loc_alloc_stat)
    !
  if (loc_alloc_stat >0) then 
  print *, "DGV_ROM_DtaDrvnColl_0D: Allocation error for variables  (fproj, collproj)"
  stop
  end if
!!!!!!!!!!!!!!!!!

!!!! PROJECTION STEP. Make sure the matrix (Projector) is set up in the memory -- we are accessing it directly
!!!! We assume that the singular vector array is matching the discretization used. 
fproj = MATMUL(f,Projector)
collproj = 0.0_DP !clean the memory

!!!! Now goes the evaluation of the collision operator of the ROM model. We used symmetry when implementing the summation. Also 
!!!! Pay attention to enumeartion of components of the three index kernel (reallyt jus tthe Galerkin discretization of the collision operator)
!!!! using a sinbgle index. It is well described in   subroutine Make_Collision_Kernel_SVD_Basis_MACRO in module DGV_dd_boltz_mpiroutines

si=0 ! Single index points before the first record

do m = 1,k_end ! we only focus on these values of k
   ! for each new value of k we add "back slab" and then the "right side slab"
   ! Back slab goes first: 
   j = m
   do k = 1,m-1
    do i = 1,m 
      si=si+1
      if (i/=j) then
         collproj(k) = collproj(k) + ROMKrnl(si)*fproj(i)*fproj(j)*2.0_DP ! Off diagonal ters of the sum are doubles because fo the symmetry of A and only upper diagonal summation 
      else 
         collproj(k) = collproj(k) + ROMKrnl(si)*fproj(i)*fproj(j)        ! this term falls on the diagonal 
      end if 
    end do 
   end do 
   ! right side slab is next  
   k = m   
   do j=1,k
    do i=1,j
      si=si+1
      if (i/=j) then
         collproj(k) = collproj(k) + ROMKrnl(si)*fproj(i)*fproj(j)*2.0_DP ! Off diagonal ters of the sum are doubles because fo the symmetry of A and only upper diagonal summation 
      else 
         collproj(k) = collproj(k) + ROMKrnl(si)*fproj(i)*fproj(j)        ! this term falls on the diagonal 
      end if 
    end do 
   end do  
  ! all done for this value of m
end do         
! The last step is to recover the solution 
coll = MATMUL(Projector,collproj)
deallocate(fproj,collproj) 

!!! All done! 

end subroutine DGV_ROM_DtaDrvnColl_0D

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!  subroutine DGV_ROM_SVZrBasisColl_0D(f, coll)
!
!  This subroutine is evaluating an approximation of the Boltzmann collision operator using ROM that is obtained using 
!  a basis obtained by SVD of solutions to a class of problem. 
!
!  A solution on a discrete mesh is passed to the subroutine. It is projected to the low dimensional model. 
!  The collision operator is evaluated using m^3 where m is the dimensionality of the ROM. Then the low 
!  dimensional collision operator is recovered on the original mesh. 
!
! 
!  Make sure that Init0D_DataDrvnBoltzn is called before this subrouinte is used. It will set up the variables
! 
! 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine DGV_ROM_SVZrBasisColl_0D(Df, coll)

intrinsic MATMUL

real (DP), dimension (:), intent (in) :: Df ! array containing solution on the mesh
real (DP), dimension (:), intent (out) :: coll ! array containing solution on the mesh

!!!
real (DP), dimension (:), allocatable :: fproj ! ROM representation of the solution 
real (DP), dimension (:), allocatable :: collproj ! ROM representation of the solution 

!!!
integer (I4B) :: i,j,k,m, k_end, si ! Scrap counters
integer (I4B) :: mm ! num of records in singular vecotr
integer (I4B) :: loc_alloc_stat ! to keep allocation status

!!!! 
!! Matrices Project, Recover and ROMKrnl are set up by Init0D_DataDrvnBoltzn
!! Make sure Init0D_DataDrvnBoltzn has been called. 
!!!!
k_end = size(Projector,2) 
mm = size(Projector,1)

!!!!!!!!!!!! A couple os sanity checks: 
if (mm /= size(Df,1)) then   ! these sizes have to be the same. There is more to it, but this is a first check
  print *, "DGV_ROM_DtaDrvnColl_0D: size of projection matrix does not match size of solution. Stop"
  stop
end if 
if (k_end*((k_end*(k_end+1))/2) /= size(ROMKrnl,1)) then   ! these sizes have to be the same. There is more to it, but this is a first check
  print *, "DGV_ROM_DtaDrvnColl_0D: size of ROM kernel array does not match size of ROM model. Stop "
  stop
end if 
!!!!!!!!!!!! end sanity check 

!!!!! Set up the array for the ROM variable: 
allocate (fproj(1:k_end),collproj(1:k_end), stat=loc_alloc_stat)
    !
  if (loc_alloc_stat >0) then 
  print *, "DGV_ROM_DtaDrvnColl_0D: Allocation error for variables  (fproj, collproj)"
  stop
  end if
!!!!!!!!!!!!!!!!!

!!!! PROJECTION STEP. Make sure the matrix (Projector) is set up in the memory -- we are accessing it directly
!!!! We assume that the singular vector array is matching the discretization used. 
fproj = MATMUL(Df,Projector)
collproj = 0.0_DP !clean the memory

!!!! Now goes the evaluation of the collision operator of the ROM model. We used symmetry when implementing the summation. Also 
!!!! Pay attention to enumeartion of components of the three index kernel (reallyt jus tthe Galerkin discretization of the collision operator)
!!!! using a sinbgle index. It is well described in   subroutine Make_Collision_Kernel_SVD_Basis_MACRO in module DGV_dd_boltz_mpiroutines

!!!!!!! First we evaluate quadratic term

si=0 ! Single index points before the first record

do m = 1,k_end ! we only focus on these values of k
   ! for each new value of k we add "back slab" and then the "right side slab"
   ! Back slab goes first: 
   j = m
   do k = 1,m-1
    do i = 1,m 
      si=si+1
      if (i/=j) then
         collproj(k) = collproj(k) + ROMKrnl(si)*fproj(i)*fproj(j)*2.0_DP ! Off diagonal ters of the sum are doubles because fo the symmetry of A and only upper diagonal summation 
      else 
         collproj(k) = collproj(k) + ROMKrnl(si)*fproj(i)*fproj(j)        ! this term falls on the diagonal 
      end if 
    end do 
   end do 
   ! right side slab is next  
   k = m   
   do j=1,k
    do i=1,j
      si=si+1
      if (i/=j) then
         collproj(k) = collproj(k) + ROMKrnl(si)*fproj(i)*fproj(j)*2.0_DP ! Off diagonal ters of the sum are doubles because fo the symmetry of A and only upper diagonal summation 
      else 
         collproj(k) = collproj(k) + ROMKrnl(si)*fproj(i)*fproj(j)        ! this term falls on the diagonal 
      end if 
    end do 
   end do  
  ! all done for this value of m
end do         
! The last step is to recover the solution 

!!!!!! Second, we evaluate the linear term and add it to the quadratic term of the collision operator
collproj = collproj + MATMUL(LinROMKrnl,fproj)

!!!!!!! Next we recover the collision operator. 
coll = MATMUL(Projector,collproj)
deallocate(fproj,collproj) 

!!! All done! 

end subroutine DGV_ROM_SVZrBasisColl_0D

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!  subroutine DGV_ROM_SVZrBasisColl_0D(f, coll)
!
!  This subroutine is evaluating an approximation of the Boltzmann collision operator using ROM that is obtained using 
!  a basis obtained by SVD of solutions to a class of problem. 
!
!  This subroutine only uses the linear term. 
!
!  A solution on a discrete mesh is passed to the subroutine. It is projected to the low dimensional model. 
!  The collision operator is evaluated using m^3 where m is the dimensionality of the ROM. Then the low 
!  dimensional collision operator is recovered on the original mesh. 
!
! 
!  Make sure that Init0D_DataDrvnBoltzn is called before this subrouinte is used. It will set up the variables
! 
! 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine DGV_ROM_SVZrBasisLinColl_0D(Df, coll)

intrinsic MATMUL

real (DP), dimension (:), intent (in) :: Df ! array containing solution on the mesh
real (DP), dimension (:), intent (out) :: coll ! array containing solution on the mesh

!!!
real (DP), dimension (:), allocatable :: fproj ! ROM representation of the solution 
real (DP), dimension (:), allocatable :: collproj ! ROM representation of the solution 

!!!
integer (I4B) :: i,j,k,m, k_end, si ! Scrap counters
integer (I4B) :: mm ! num of records in singular vecotr
integer (I4B) :: loc_alloc_stat ! to keep allocation status

!!!! 
!! Matrices Project, Recover and ROMKrnl are set up by Init0D_DataDrvnBoltzn
!! Make sure Init0D_DataDrvnBoltzn has been called. 
!!!!
k_end = size(Projector,2) 
mm = size(Projector,1)

!!!!!!!!!!!! A couple os sanity checks: 
if (mm /= size(Df,1)) then   ! these sizes have to be the same. There is more to it, but this is a first check
  print *, "DGV_ROM_DtaDrvnColl_0D: size of projection matrix does not match size of solution. Stop"
  stop
end if 
if (k_end*((k_end*(k_end+1))/2) /= size(ROMKrnl,1)) then   ! these sizes have to be the same. There is more to it, but this is a first check
  print *, "DGV_ROM_DtaDrvnColl_0D: size of ROM kernel array does not match size of ROM model. Stop "
  stop
end if 
!!!!!!!!!!!! end sanity check 

!!!!! Set up the array for the ROM variable: 
allocate (fproj(1:k_end),collproj(1:k_end), stat=loc_alloc_stat)
    !
  if (loc_alloc_stat >0) then 
  print *, "DGV_ROM_DtaDrvnColl_0D: Allocation error for variables  (fproj, collproj)"
  stop
  end if
!!!!!!!!!!!!!!!!!

!!!! PROJECTION STEP. Make sure the matrix (Projector) is set up in the memory -- we are accessing it directly
!!!! We assume that the singular vector array is matching the discretization used. 
fproj = MATMUL(Df,Projector)
collproj = 0.0_DP !clean the memory

!!!!!! Second, we evaluate the linear term and add it to the quadratic term of the collision operator
collproj = MATMUL(LinROMKrnl,fproj)

!!!!!!! Next we recover the collision operator. 
coll = MATMUL(Projector,collproj)
deallocate(fproj,collproj) 

!!! All done! 

end subroutine DGV_ROM_SVZrBasisLinColl_0D



!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!  subroutine DGV_ROM_DDColl_MxdTrms_0D(f,g,coll)
!
!  This subroutine is evaluating an approximation of the Boltzmann collision operator using ROM that is obtained using 
!  a basis obtained by SVD of solutions to a class of problem. 
!
!  A solution on a discrete mesh is passed to the subroutine. It is projected to the low dimensional model. 
!  The collision operator is evaluated using m^3 where m is the dimensionality of the ROM. Then the low 
!  dimensional collision operator is recovered on the original mesh. 
!
! 
!  Make sure that Init0D_DataDrvnBoltzn is called before this subrouinte is used. It will set up the variables
! 
! 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine DGV_ROM_DDColl_MxdTrms_0D(f,g,coll)

intrinsic MATMUL

real (DP), dimension (:), intent (in) :: f ! array containing solution on the mesh
real (DP), dimension (:), intent (in) :: g ! array containing solution on the mesh
real (DP), dimension (:), intent (out) :: coll ! array containing solution on the mesh

!!!
real (DP), dimension (:), allocatable :: fproj ! ROM representation of the function f
real (DP), dimension (:), allocatable :: gproj ! ROM representation of the function g 
real (DP), dimension (:), allocatable :: collproj ! ROM representation of the collision operator 

!!!
integer (I4B) :: i,j,k,m, k_end, si ! Scrap counters
integer (I4B) :: mm ! num of records in singular vecotr
integer (I4B) :: loc_alloc_stat ! to keep allocation status
!!!! 
!! Matrices Project, Recover and ROMKrnl are set up by Init0D_DataDrvnBoltzn
!! Make sure Init0D_DataDrvnBoltzn has been called. 
!!!!
k_end = size(Projector,2) 
mm = size(Projector,1)

!!!!!!!!!!!! A couple os sanity checks: 
if (mm /= size(f,1)) then   ! these sizes have to be the same. There is more to it, but this is a first check
  print *, "DGV_ROM_DtaDrvnColl_0D: size of projection matrix does not match size of solution. Stop"
  stop
end if 
if (k_end*((k_end*(k_end+1))/2) /= size(ROMKrnl,1)) then   ! these sizes have to be the same. There is more to it, but this is a first check
  print *, "DGV_ROM_DtaDrvnColl_0D: size of ROM kernel array does not match size of ROM model. Stop "
  stop
end if 
!!!!!!!!!!!! end sanity check 

!!!!! Set up the array for the ROM variable: 
allocate (fproj(1:k_end),gproj(1:k_end),collproj(1:k_end), stat=loc_alloc_stat)
    !
  if (loc_alloc_stat >0) then 
  print *, "DGV_ROM_DtaDrvnColl_0D: Allocation error for variables  (fproj, collproj)"
  stop
  end if
!!!!!!!!!!!!!!!!!

!!!! PROJECTION STEP. Make sure the matrix (Projector) is set up in the memory -- we are accessing it directly
!!!! We assume that the singular vector array is matching the discretization used. 
fproj = MATMUL(f,Projector)
gproj = MATMUL(g,Projector)
collproj = 0.0_DP !clean the memory

!!!! Now goes the evaluation of the collision operator of the ROM model. We used symmetry when implementing the summation. Also 
!!!! Pay attention to enumeartion of components of the three index kernel (reallyt jus tthe Galerkin discretization of the collision operator)
!!!! using a sinbgle index. It is well described in   subroutine Make_Collision_Kernel_SVD_Basis_MACRO in module DGV_dd_boltz_mpiroutines

si=0 ! Single index points before the first record

do m = 1,k_end ! we only focus on these values of k
   ! for each new value of k we add "back slab" and then the "right side slab"
   ! Back slab goes first: 
   j = m
   do k = 1,m-1
    do i = 1,m 
      si=si+1
      if (i/=j) then
         collproj(k) = collproj(k) + ROMKrnl(si)*(fproj(i)*gproj(j)+fproj(j)*gproj(i)) ! Off diagonal ters of the sum are doubles because fo the symmetry of A and only upper diagonal summation 
      else 
         collproj(k) = collproj(k) + ROMKrnl(si)*fproj(i)*gproj(j)        ! this term falls on the diagonal 
      end if 
    end do 
   end do 
   ! right side slab is next  
   k = m   
   do j=1,k
    do i=1,j
      si=si+1
      if (i/=j) then
         collproj(k) = collproj(k) + ROMKrnl(si)*(fproj(i)*gproj(j)+fproj(j)*gproj(i))  ! Off diagonal ters of the sum are doubles because fo the symmetry of A and only upper diagonal summation 
      else 
         collproj(k) = collproj(k) + ROMKrnl(si)*fproj(i)*gproj(j)        ! this term falls on the diagonal 
      end if 
    end do 
   end do  
  ! all done for this value of m
end do         
! The last step is to recover the solution 
coll = MATMUL(Projector,collproj)

deallocate(fproj,gproj,collproj) 
!!! All done! 

end subroutine DGV_ROM_DDColl_MxdTrms_0D


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!
! Init0D_DataDrvnBoltzn
!
! This subroutine sets up arrays necessary to run DGV_ROM_DtaDrvnColl_0D
!
! In particualr, it reads from the hard drive and sets global allocatable arrays ROMKrnl and Projector
!
!
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
subroutine Init0D_DataDrvnBoltzn

use DGV_commvar, only: nodes_u

integer (I4B), parameter :: MaxRomSize = 100 ! The maximum allowed size of ROM.
!!!!!!!!!!!!!!!
real (DP), dimension (:,:), pointer :: SVects ! array to keep singular vectors.
real (DP), dimension (:), pointer :: CKrnl  ! array to keep the collision kernel components -- using single index and the conventions to enumerate as above. 
real (DP), dimension (:,:), pointer :: BKrnl  ! array to keep the linear collision kernel components -- ONly is used with the SV Zero Basis. 
!!!!!!!!!!!!!!!
integer(I4B) :: sis, sie,k,mm ! scrap variables 
integer (I4B) :: loc_alloc_stat ! to keep allocation status



!!! First we read a couple of parameters that will be used. 
call SetDGVParams_DataDrivenBLZM("DtaDrvnBparameters.dat",0) ! this one only needs to be called at the master node. 

!!! Next we will need to read the singular vector kernel from the hard drive
call ReadCKrnl_DtaDrvnB(SVKrnl_name,CKrnl,sis,sie)
if (sis /= 1)  then   ! sanity check 
  print *, "Init0D_DataDrvnBoltzn: index of first component of the kernel array CKrnl is not equal to 1. Stop. sis=", sis
  stop
end if 

!!!!!!!!!!!!!!!!!! we also read the signuilar vectors
call ReadSingVect_DtaDrvnB(SVfile_name,SVects) ! This will allocate the array of singular vectors and use the space to read the singular vectors from a file on the hard drive. 
                             ! Name of the file is in variable svdname 
                             ! Values of singular vecotors are in array pointed to by SVects 

!!!! Now the array CKrnl has all of the components of singular vector 
!!!! we need to find out how many components k to use in the SVD decomposition.
do k = 1,MaxRomSize  !!! Attention: hard coded the maximum size of the ROM to be 100
 if ((k+1)*(((k+1)*(k+2))/2) > size(CKrnl,1)) then   ! these sizes have to be the same. There is more to it, but this is a first check
  print *, "Init0D_DataDrvnBoltzn: The size of the ROM supported by the binary kernel array is k =  ", k
  exit
 end if 
end do 

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
!!!!!!!!!!! Sanity check k must be greater then or equal to k_tgt -- the target size of the basis. 
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
if (k < k_tgt) then 
  print *, "Init0D_DataDrvnBoltzn: Binary kernel array does not have enought components k= to support target size k_tgt=", k, k_tgt 
  stop
end if   
!!!!!!!!!!! 

!!!!! Note that k_tgt contains the target size of the rom. 
!!!!! Set up the array for the ROM projector and the kernel: 
!!!!! We use the global variable k_tgt -- the desired size of ROM basis 
mm=size(nodes_u,1)
allocate (Projector(1:mm,1:k_tgt),ROMKrnl(1:k_tgt*((k_tgt*(k_tgt+1))/2)), stat=loc_alloc_stat)
    !
  if (loc_alloc_stat >0) then 
  print *, "Init0D_DataDrvnBoltzn: Allocation error for variables  (Projector, ROMKrnl)"
  stop
  end if
!!!!!!!!!!!!!!!!! next we populate the global arrays: 
Projector(:,1:k_tgt) = SVects(:,1:k_tgt)
ROMKrnl(1:k_tgt*((k_tgt*(k_tgt+1))/2)) = CKrnl(sis:sis+k_tgt*((k_tgt*(k_tgt+1))/2)-1)
!!! Deallocate the arrays CKrnl and SVects

deallocate(CKrnl,SVects)


!!!!!!!!!!!!!!!!!!!!!!!
!!!! This portion is only envoked if SV zero basis is used. In this case 
!! collision operator uses linear -quadratic decomposition for Df to evaluate collision operator 
!! and the code will look for linear kernel BKrnl
if (flag_SVZeroBasisInUse) then 
  !!! Next we will need to read the singular vector kernel from the hard drive
  call ReadBKrnl_DtaDrvnB(SVLinKrnl_name,BKrnl,sis)  ! sis contains the size of the square matrix
  if (sis < k_tgt)  then   ! sanity check 
   print *, "Init0D_DataDrvnBoltzn: dim of lin ROM kernel is less than supplied size of ROM basis. Stop. sis=, k_tgt=", sis, k_tgt
   stop
  end if 

  !!! Next we will need to allocate memory for linar kernel matrix 
  allocate (LinROMKrnl(1:k_tgt,1:k_tgt), stat=loc_alloc_stat)
  !!!
  if (loc_alloc_stat >0) then 
   print *, "Init0D_DataDrvnBoltzn: Allocation error for variables  (LinROMKrnl)"
   stop
  end if
  
  !!!! Next we set up the Linear Kernel Matrix
  LinROMKrnl(:,:) = BKrnl(1:k_tgt,1:k_tgt)
  deallocate(BKrnl)
end if 
!!  End of SV Zero basis portion   
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
end subroutine Init0D_DataDrvnBoltzn


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! ROMOrthCompESBGKDamp(f,Df,RHS)
!
! This subrouinte will add a damping -af term to the right hand side that 
! will only affect the portion of the solution that is orthrogonal to the ROM basis
!
! The rate of damping is based on the ES-BGK collision frequency 
! Here, the RHS = -nu * (fperp)
! where
! nu = collision frequency
! fperp = portion of the solution that is orthogonal to the ROM basis 
! f = solution
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

subroutine ROMOrthCompESBGKDamp(f,Df,RHS)

use DGV_distributions_mod
use DGV_dgvtools_mod
use DGV_commvar, only: nodes_gwts, nodes_u, nodes_v, nodes_w, &
				   alpha, gas_viscosity, gas_T_reference, gas_alpha, C_inf, gasR

real (DP), dimension (:), intent (in) :: f ! the components of the solution at the current time step. 
real (DP), dimension (:), intent (in) :: Df ! =f-f_maxwell -- difference bvetweent he solution and the local maxwellian 
real (DP), dimension (:), intent (out) :: RHS ! the value of the collision operator for each component of the solution.


real (DP), dimension (:), allocatable :: fperp ! portion of the solution that is orthogonal to the ROM basis 
real (DP) :: u_0, v_0, w_0 ! bulk velocities
real (DP) :: n ! density
real (DP) :: T ! temperature
!real (DP) :: Determinant ! the determinant of the Tensor
real (DP) :: Pressure
real (DP) :: nu ! this is the collision frequency term

real (DP), parameter :: kBoltzmann = 1.3806503D-23
integer :: loc_alloc_stat

! compute the macroparameters for use in the tensor computation
!!!!!!!!
! density (number density)
n=sum(f*nodes_gwts)
!!!!!!!!
! momentum 
u_0=sum(f*nodes_gwts*nodes_u)/n
v_0=sum(f*nodes_gwts*nodes_v)/n
w_0=sum(f*nodes_gwts*nodes_w)/n
!!!!!!!!
! temperature
T = sum(f*nodes_gwts*((nodes_u-u_0)**2+(nodes_v-v_0)**2+(nodes_w-w_0)**2))/n/3.0_DP*2.0_DP ! dimensionless temperature
!!
allocate (fperp(1:size(f,1)), stat=loc_alloc_stat)
if (loc_alloc_stat >0) then 
 print *, "EvalColESBGK: Allocation error for variables (f0)"
 stop
end if

fperp =  Df - MATMUL(Projector,MATMUL(Df,Projector))
! the tensor and its corresponding inverse and determinant is computed here
! now to evaluate the collision requency term
Pressure = n*T ! dimensionless Pressure is computed here
nu = Pressure/((1-alpha))*((gas_T_reference/C_inf**2*2.0d0*gasR)/T)**gas_alpha ! final dimensionless nu ! have gas_T_reference be dimensionless?
RHS = -nu*fperp

deallocate (fperp)
!
end subroutine ROMOrthCompESBGKDamp




end module DGV_data_driven_boltz